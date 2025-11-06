# Packages
using JuMP
using HiGHS

using DataFrames
using CSV

using Printf

# Model
model = Model(HiGHS.Optimizer)

# Input (prices, amount)
# df = DataFrame(a = [1, 2, 6], b = [4, 5, 3], c = [7, 8, 9])
# CSV.write("file.csv", df)
df_new = CSV.read("results/julia_input.csv", DataFrame)

length = nrow(df_new)

# Variables
@variable(model, x[1:length] >= 0, integer=true)
@variable(model, y[1:length] >= 0, integer=true)
@variable(model, b, binary=true)

# Constraints
for (i, row) in enumerate( eachrow( df_new ) ) 
    @constraint(model, x[i] + y[i] == row[3]) 
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
println(model)

# Solve & results
optimize!(model)
println(termination_status(model))
println(objective_value(model))
#println(value(x))
#println(value(y))
#println(value(b))

@printf("Lego price: %f\n", sum(value(x) .* df_new.lego_price))
@printf("Andrea price: %f\n", sum(value(y) .* df_new.price))
@printf("MWST: %f\n", 0.081*(sum(value(y) .* df_new.price) + 23*value(b)))
@printf("Warenwertzuschlag: %f\n", 0.03*(sum(value(y) .* df_new.price) + 23*value(b)))
@printf("MWST (Verzollung): %f\n", 0.081*(13*value(b) + 0.03*(sum(value(y) .* df_new.price) + 23*value(b))))

# TODO
# Check which pieces change between the two optimisation models
# Calculate total price if using max from Lego and rest from Andrea (and vice versa)
# -> compare those prices to the objective values of the two optimisation models
# Check difference between solutions to model 1 with all additional costs or only MWST

