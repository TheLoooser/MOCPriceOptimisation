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
    3.5 3.5 3.5;  # BlackCat
    # 3 6.4 15.5;  # SwissBrickBank x Panda Bricks
    # 3.2 8 8;  # Playmondo
    # 4.5 9 9;  # 500 to moon
    # 3.7 8.5 8.5;  # Swiss Brickshop
    4.9 0 0;  # Briques 48
]
shipping_costs = [
    3.0 4.5 6.4 15.5 20.0;
    1.8 2.7 3.2 8.0 8.0;
    4.5 9.0 15.0 15 15.0;
    3.2 3.7 8.5 11.5 11.5; 
]
weight_limits = [
    0 65 100 290 1700 10000;  # SWissBrickBank x Panda Bricks
    0 90 140 250 2000 10000;  # Playmondo
    0 230 2000 10000 10000 10000;  # 500tomoon
    0 80 200 2000 10000 10000;  # Swiss BrickShop
]
shipping_eu = [10]  # Andrea
thresholds = [
    0 50 100 100000;
    0 0 0 100000;
    # 0 10 70 100000;
    # 0 20 100 100000;
    # 0 18 100 100000;
    # 0 12 100 100000;
    0 200 100000 100000;
]

len = nrow(input)
nbuckets = size(shipping_ch)[2]
nweightbuckets = size(shipping_costs)[2]
nchstores = size(shipping_ch)[1]
nchstores_weight = size(weight_limits)[1]
nchstores_total = nchstores + nchstores_weight
nstores = nchstores_total + size(shipping_eu)[1]
neustores = size(shipping_eu)[1]

println(nchstores)
println(nchstores_weight)
println(nchstores_total)
println(nstores)

# Variables
@variable(model, x[1:len, 1:nstores] >= 0, integer=true)
@variable(model, b[1:nchstores, 1:nbuckets], binary=true)
@variable(model, c[1:neustores] >= 0, integer=true)
@variable(model, d[1:nchstores_weight, 1:nweightbuckets], binary=true)

# Constraints
# - Quantities
for (i, row) in enumerate( eachrow( input ) ) 
    @constraint(model, sum(x[i, j] for j in 1:nstores) >= row[4]) # Total quantity
    for j in 1:nstores
        @constraint(model, x[i, j] <= row[4 + 2*j]) # Store quantity
    end
end
# - EU shipping
for j in nchstores_total + 1:nstores
    idx = nstores - j + 1
    @constraint(model, sum(input[i, 2*j + 3]*x[i, j] for i in 1:len) <= (60 - shipping_eu[idx])*c[idx]) # Max shipping cost
end
# - CH shipping
# -- Order cost
for i in 1:nchstores_total - nchstores_weight
    @constraint(model, sum(input[k, 2*i + 3] * x[k, i] for k in 1:len) <= 
                        sum(thresholds[i, j+1] * b[i, j] for j in 1:nbuckets))
    @constraint(model, sum(input[k, 2*i + 3] * x[k, i] for k in 1:len) >= 
                        sum(thresholds[i, j] * b[i, j] for j in 1:nbuckets))
    @constraint(model, sum(b[i, j] for j in 1:nbuckets) <= 1)
end
# # -- Weight cost
for i in nchstores_weight:nchstores_total
    idx = i - nchstores_weight + 1
    println(i)
    println(idx)
    @constraint(model, 1.15*sum(x[k, i] for k in 1:len) <= 
                        sum(weight_limits[idx, j+1] * d[idx, j] for j in 1:nweightbuckets))
    @constraint(model, 1.15*sum(x[k, i] for k in 1:len) >= 
                        sum(weight_limits[idx, j] * d[idx, j] for j in 1:nweightbuckets))
    @constraint(model, sum(d[idx, j] for j in 1:nweightbuckets) <= 1)
end


##################################
# FIRST OBJECTIVE & OPTIMISATION #
##################################
# Objective
@objective(model, Min, sum(input[i, 2*j + 3] * x[i, j] for i in 1:len for j in 1:nstores) +
                        sum(c[j-nchstores_total]*shipping_eu[j-nchstores_total] for j in nchstores_total+1:nstores) + 
                        sum(shipping_ch[i, j]*b[i, j] for i in 1:nchstores for j in 1:nbuckets) +
                        sum(shipping_costs[i, j]*d[i, j] for i in 1:nchstores_weight for j in 1:nweightbuckets)
                        )

# Solve & results
optimize!(model)
println(objective_value(model))

println(value(b))
println(value(d))
println(value(c))

for s in 1:nstores
    @printf("Store Nr. %i: %f\n", s, sum(value(x)[i, s] .* input[i, 2*s + 3] for i in 1:len))
end

# TODO:
# Get more stores
# Check minimum order value (should probably not matter because of shipping costs)
df = DataFrame(value(x), :auto)
out = DataFrame()
out[!, "Part"] = input.part_nr
out[!, "Color"] = input.colour
for s in 1:nstores
    out[!, "Quantity"] = df[!, s]
    out[!, "Quantity"] = round.(Int, out[!,:Quantity])  # Int.(out[!,:Quantity])
    CSV.write(string("results/", s, ".csv"), out)
end

# TODO
# Finish readme
# Verify that results (andrea & lego & missing) cover all parts (and quantities)
# -> in julia (before it is not possible)
# Add lusher tree MOC to the mix
# -> create new parts list in rebrickable (combine parts of both MOCs)
# -> Use these lists to calculate optimal price (do not forget additional instruction cost)
# Expand excel with prices from different brickowl stores (incl swiss stores)

