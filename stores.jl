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
input = CSV.read("results/julia_input_multiple_stores.csv", DataFrame)
shipping = [0,10,10]

len = nrow(input)
nstores = length(shipping)

# Variables
@variable(model, x[1:len, 1:nstores] >= 0, integer=true)
@variable(model, b[1:nstores] >= 0, integer=true)

# Constraints
for (i, row) in enumerate( eachrow( input ) ) 
    @constraint(model, sum(x[i, j] for j in 1:nstores) >= row[4]) # Total quantity
    for j in 1:nstores
        @constraint(model, x[i, j] <= row[4 + 2*j]) # Store quantity
    end
end
for j in 1:nstores
    @constraint(model, sum(input[i, 2*j + 3]*x[i, j] for i in 1:len) <= (60 - shipping[j])*b[j]) # Max shipping cost
end


##################################
# FIRST OBJECTIVE & OPTIMISATION #
##################################
# Objective
@objective(model, Min, sum(input[i, 2*j + 3] * x[i, j] for i in 1:len for j in 1:nstores))

# Solve & results
optimize!(model)
println(objective_value(model))

# TODO: Print variable values
# add constraint s.t. lego shipping price is 0 if sum > 100
# Put html filse in data subfolder
# Get more stores
# Use proper shipping prices

# TODO
# Finish readme
# Verify that results (andrea & lego & missing) cover all parts (and quantities)
# -> in julia (before it is not possible)
# Add lusher tree MOC to the mix
# -> create new parts list in rebrickable (combine parts of both MOCs)
# -> Use these lists to calculate optimal price (do not forget additional instruction cost)
# Expand excel with prices from different brickowl stores (incl swiss stores)


#@printf("Lego price: %f\n", sum(value(x) .* input.lego_price))

