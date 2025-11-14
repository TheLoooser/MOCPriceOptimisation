# Packages
using JuMP
using HiGHS

using DataFrames
using CSV

using Printf

# Model
model = Model(HiGHS.Optimizer)

# Input (prices, amount, quantities)
df_new = CSV.read("results/julia_input.csv", DataFrame)

length = nrow(df_new)

# Variables
@variable(model, x[1:length] >= 0, integer=true)
@variable(model, y[1:length] >= 0, integer=true)
@variable(model, b, binary=true)

# Constraints
for (i, row) in enumerate( eachrow( df_new ) ) 
    @constraint(model, x[i] + y[i] == row[3])
    @constraint(model, x[i] <= row[4])
    @constraint(model, y[i] <= row[5])
end
@constraint(model, sum(y[i] for i in 1:length) <= 100000*b)

# Objective
# 1) Incl. custom tariffs
@objective(model, Min, sum(df_new[i, 1]*x[i] + df_new[i,2]*y[i] for i in 1:length) # Warenwert
                        + 0.081*(sum(df_new[i,2]*y[i] for i in 1:length) + 23*b) # MWST
                        + 13*b # Verzollungskosten (Dienstleistungsgebühr)
                        + 0.03*(sum(df_new[i,2]*y[i] for i in 1:length) + 23*b) # Verzollungskosten (Warenwertzuschlag)
                        + 0.081*(13*b + 0.03*(sum(df_new[i,2]*y[i] for i in 1:length) + 23*b)) # MWST auf Verzollungskosten
                        )
# 2) Price only
# @objective(model, Min, sum(df_new[i, 1]*x[i] + df_new[i,2]*y[i] for i in 1:length))


# Final model
# println(model)

# Solve & results
optimize!(model)
println(objective_value(model))

@printf("Lego price: %f\n", sum(value(x) .* df_new.lego_price))
@printf("Andrea price: %f\n", sum(value(y) .* df_new.price))
@printf("MWST: %f\n", 0.081*(sum(value(y) .* df_new.price) + 23*value(b)))
@printf("Warenwertzuschlag: %f\n", 0.03*(sum(value(y) .* df_new.price) + 23*value(b)))
@printf("MWST (Verzollung): %f\n", 0.081*(13*value(b) + 0.03*(sum(value(y) .* df_new.price) + 23*value(b))))

# TODO
# Check which pieces change between the two optimisation models
# Check difference between solutions to model 1 with all additional costs or only MWST
# Print part number of pieces which are in x and y (>= 0)

# Create rebrickable part list for the different stores
lego = DataFrame()
lego[!, "Part"] = df_new.part_nr
lego[!, "Color"] = df_new.colour
lego[!, "Quantity"] = value(x)
lego[!, :Quantity] = Int.(lego[!,:Quantity])

CSV.write("results/lego.csv", lego)

brickowl = DataFrame()
brickowl[!, "Part"] = df_new.part_nr
brickowl[!, "Color"] = df_new.colour
brickowl[!, "Quantity"] = value(y)
brickowl[!, :Quantity] = Int.(brickowl[!,:Quantity])

CSV.write("results/brickowl.csv", brickowl)

# List pieces which were selected in both stores
brickowl[!, "Quantity2"] = value(x)
brickowl[!, "Quantity3"] = df_new.quantity

for (i, row) in enumerate( eachrow( brickowl ) ) 
    if row[3] > 0 && row[4] > 0
        println(row)
    end
end
