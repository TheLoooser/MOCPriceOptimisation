# Packages
using JuMP
using HiGHS

using DataFrames
using CSV

using Printf


##################################
# MODEL, VARIABLES & CONSTRAINTS #
##################################

# Model
model = Model(HiGHS.Optimizer)

# Input (prices, amount, quantities)
input = CSV.read("results/julia_input.csv", DataFrame)

length = nrow(input)

# Variables
@variable(model, x[1:length] >= 0, integer=true)
@variable(model, y[1:length] >= 0, integer=true)
@variable(model, b, binary=true)

# Constraints
for (i, row) in enumerate( eachrow( input ) ) 
    @constraint(model, x[i] + y[i] == row[3])
    @constraint(model, x[i] <= row[4])
    @constraint(model, y[i] <= row[5])
end
@constraint(model, sum(y[i] for i in 1:length) <= 100000*b)


##################################
# FIRST OBJECTIVE & OPTIMISATION #
##################################
# Objective
# 1) Incl. custom tariffs
@objective(model, Min, sum(input[i, 1]*x[i] + input[i,2]*y[i] for i in 1:length) # Warenwert
                        + 0.081*(sum(input[i,2]*y[i] for i in 1:length) + 23*b) # MWST
                        + 13*b # Verzollungskosten (Dienstleistungsgebühr)
                        + 0.03*(sum(input[i,2]*y[i] for i in 1:length) + 23*b) # Verzollungskosten (Warenwertzuschlag)
                        + 0.081*(13*b + 0.03*(sum(input[i,2]*y[i] for i in 1:length) + 23*b)) # MWST auf Verzollungskosten
                        )

# Final model
# println(model)

# Solve & results
optimize!(model)
println(objective_value(model))

@printf("Lego price: %f\n", sum(value(x) .* input.lego_price))
@printf("BrickOwl price: %f\n", sum(value(y) .* input.price))
@printf("MWST: %f\n", 0.081*(sum(value(y) .* input.price) + 23*value(b)))
@printf("Warenwertzuschlag: %f\n", 0.03*(sum(value(y) .* input.price) + 23*value(b)))
@printf("MWST (Verzollung): %f\n", 0.081*(13*value(b) + 0.03*(sum(value(y) .* input.price) + 23*value(b))))


##################################
########## PART LISTS ############
##################################

# Create rebrickable part list for the different stores
lego = DataFrame()
lego[!, "Part"] = input.part_nr
lego[!, "Color"] = input.colour
lego[!, "Quantity"] = value(x)
lego[!, :Quantity] = Int.(lego[!,:Quantity])

CSV.write("results/lego.csv", lego)

brickowl = DataFrame()
brickowl[!, "Part"] = input.part_nr
brickowl[!, "Color"] = input.colour
brickowl[!, "Quantity"] = value(y)
brickowl[!, :Quantity] = Int.(brickowl[!,:Quantity])

CSV.write("results/brickowl.csv", brickowl)

# List pieces which were selected in both stores
brickowl[!, "Quantity2"] = value(x)
brickowl[!, "Quantity3"] = input.quantity

for (i, row) in enumerate( eachrow( brickowl ) ) 
    if row[3] > 0 && row[4] > 0
        println(row)
    end
end


##################################
## SECOND OBJECTIVE & SOLUTION ###
##################################

solutions = DataFrame()
solutions[!, "Part"] = input.part_nr
solutions[!, "Color"] = input.colour
solutions[!, "LegoPrice"] = input.lego_price
solutions[!, "BrickOwlPricer"] = input.price
solutions[!, "LegoMWST"] = value(x)
solutions[!, "BrickOwlMWST"] = value(y)

# Objective
# 2) Price only
@objective(model, Min, sum(input[i, 1]*x[i] + input[i,2]*y[i] for i in 1:length))
optimize!(model)
println(objective_value(model))

solutions[!, "Lego"] = value(x)
solutions[!, "BrickOwl"] = value(y)

# Show the difference between the solutions to the two objectives
for (i, row) in enumerate( eachrow( solutions ) ) 
    if row[5] != row[7] || row[6] != row[8]
        println(row)
    end
end


##################################
#### OBJECTIVE 2.5 & SOLUTION ####
##################################

# Objective
# 2.5) Price only and split brickowl shippments into smaller packets to avoid custom tariffs
@variable(model, c >= 0, integer=true)
@constraint(model, sum(input[i,2]*y[i] for i in 1:length) <= 51*c)
@objective(model, Min, sum(input[i, 1]*x[i] + input[i,2]*y[i] for i in 1:length) + 10.6*c)
optimize!(model)
println(objective_value(model))
println(value(c))

@printf("Lego price: %f\n", sum(value(x) .* input.lego_price))
@printf("BrickOwl price: %f\n", sum(value(y) .* input.price))
