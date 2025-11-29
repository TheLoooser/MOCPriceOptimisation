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
shipping_ch = [
    7.5 8.5 0;  # Lego
    3.5 3.5 3.5  # BlackCat
]
shipping_eu = [10]  # Andrea
thresholds = [
    0 50 100 100000;
    0 0 0 100000;
]

len = nrow(input)
nstores = size(shipping_ch)[1] + size(shipping_eu)[1]
nbuckets = size(shipping_ch)[2]
nchstores = size(shipping_ch)[1]
neustores = size(shipping_eu)[1]

# Variables
@variable(model, x[1:len, 1:nstores] >= 0, integer=true)
@variable(model, b[1:nchstores, 1:nbuckets], binary=true)
@variable(model, c[1:neustores] >= 0, integer=true)

# Constraints
for (i, row) in enumerate( eachrow( input ) ) 
    @constraint(model, sum(x[i, j] for j in 1:nstores) >= row[4]) # Total quantity
    for j in 1:nstores
        @constraint(model, x[i, j] <= row[4 + 2*j]) # Store quantity
    end
end
# @constraint(model, 100 - sum(input[i, 5]*x[i, 1] for i in 1:len) <= 100000*b[1]) # LEGO store shipping constraint
for j in nchstores+1:nstores
    idx = nstores - j + 1
    @constraint(model, sum(input[i, 2*j + 3]*x[i, j] for i in 1:len) <= (60 - shipping_eu[idx])*c[idx]) # Max shipping cost
end
for i in 1:nchstores
    @constraint(model, sum(input[k, 2*i + 3] * x[k, i] for k in 1:len) <= 
                        sum(thresholds[i, j+1] * b[i, j] for j in 1:nbuckets))
    @constraint(model, sum(input[k, 2*i + 3] * x[k, i] for k in 1:len) >= 
                        sum(thresholds[i, j] * b[i, j] for j in 1:nbuckets))
    @constraint(model, sum(b[i, j] for j in 1:nbuckets) <= 1)
end


##################################
# FIRST OBJECTIVE & OPTIMISATION #
##################################
# Objective
@objective(model, Min, sum(input[i, 2*j + 3] * x[i, j] for i in 1:len for j in 1:nstores) +
                        sum(c[j-nchstores]*shipping_eu[j-nchstores] for j in nchstores+1:nstores) + 
                        sum(shipping_ch[i, j]*b[i, j] for i in 1:nchstores for j in 1:nbuckets)
                        )

# Solve & results
optimize!(model)
println(objective_value(model))

println(value(b))
println(value(c))

# TODO: Print variable values
# add constraint s.t. lego shipping price is 0 if sum > 100
# -> Verify lego shipping cost constraint
# Add shipping constraints for different shipping costs (for Lego, CH & others)
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

