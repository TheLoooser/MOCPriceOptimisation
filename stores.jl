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
input = CSV.read("results/julia_input_multiple_stores_no_blue.csv", DataFrame)
# Shipping costs: Fixed costs (based on order value, not weight)
shipping_ch = [
    7.5 8.5 0;  # Lego
    3.5 3.5 3.5;  # BlackCat
]
# Order value threshold (when shipping price changes based on cart value)
thresholds = [
    0 50 100 100000;
    0 0 0 100000;
]
# Shipping costs: National, based on weight
shipping_costs = [
    3.0 4.5 6.4 13.9 20.9;
    3.5 9.0 12.0 21.0 21.0;
    3.0 3.4 9.0 12.0 15.0;
    #5.0 5.4 11.0 12.0 21.0; # Pauschale für Bearbeitungsgebühr 2.- CHF (bis 50.-)
    #3.8 6.3 13.1 16.1 25.1;
    1.8 2.7 3.2 8.0 8.0;
    4.5 9.0 15.0 15 15.0;
    3.0 5.4 10.5 13.5 13.5;
    #3.2 3.7 8.5 11.5 11.5;
    6.5 9.0 12.0 12.0 12.0;
    2.95 4.95 10.5 13.5 13.5;
]
# Weight limits for national stores
weight_limits = [
    0 65 100 320 1700 10000;  # SwissBrickBank x Panda Bricks
    0 40 1600 8500 10000 20000; # Brixx-Shop-Schmidt
    0 60 400 960 1800 10000; # Brick'n'Toast
    #0 20 390 1800 9400 10000; # K_K Bricks and Toys
    #0 80 200 1500 8000 10000; # Brickunion
    0 90 140 250 2000 10000;  # Playmondo
    0 230 2000 10000 10000 10000;  # 500tomoon
    0 60 420 1800 9500 10000; # HochisBricks
    #0 80 200 2000 10000 10000;  # Swiss BrickShop
    0 930 1850 9000 10000 10000; # Jura-Bricks
    0 200 500 1250 9000 9000; # welcomebricks
]

# Shipping costs: International stores (based on weight)
shipping_eu = [
    8.19 10.01 13.66 19.12; # 3 Bricks
    8.64 10.01 11.83 13.10; # Andrea
    9.65 9.65 9.65 9.65; # Brickina
    9.08 10.52 22.57 24.28; # Brick Takeover
    7.12 9.37 12.37 19.49; # Brikea
    4.78 9.15 14.15 20.03; # JustBrix
    8.18 11.83 27.30 41.87; # kleinesteinewelt
    10.01 11.83 13.65 15.47; # LA_Brickstore
    12.00 17.62 24.00 24.00; # Little Big Store
    10.93 15.48 21.4 21.4; # Lo Stanzino 
    10.01 16.39 22.76 29.12; # Stalaedla
    9.79 10.01 11.38 13.66; # Vividbricks
]
# Weight limit for international stores
weight_limits_eu = [
    0 200 400 800 1600;
    0 160 340 520 700;
    0 5000 1000 3000 10000;
    0 450 850 1000 3000;
    0 70 200 420 800;
    0 80 280 400 1600;
    0 200 400 1700 4500;
    0 200 400 500 600;
    0 300 700 1000 2000;
    0 100 300 1000 2000;
    0 400 800 1200 1600;
    0 100 300 650 1600;
]

# Discount value for lego store
discount = 0.92

# Constants
len = nrow(input)
nbuckets = size(shipping_ch)[2]
nweightbuckets = size(shipping_costs)[2]
nweightbuckets_eu = size(shipping_eu)[2]
nchstores = size(shipping_ch)[1]
nchstores_weight = size(weight_limits)[1]
nchstores_total = nchstores + nchstores_weight
nstores = nchstores_total + size(shipping_eu)[1]
neustores = size(shipping_eu)[1]

# Variables
@variable(model, x[1:len, 1:nstores] >= 0, integer=true)  # part i is bought x[i,j] times from store j
@variable(model, b[1:nchstores, 1:nbuckets], binary=true)  # True, if buying from store i in price category j
@variable(model, d[1:nchstores_weight, 1:nweightbuckets], binary=true)  # True, if buying from store i in weight bucket j
@variable(model, f[1:neustores, 1:nweightbuckets_eu] >= 0, integer=true)  # True, if buying from store i in weight bucket j
@variable(model, z[1:len], binary=true)

# Constraints
# - Quantities
for (i, row) in enumerate( eachrow( input ) ) 
    @constraint(model, sum(x[i, j] for j in 1:nstores) >= row[4]) # Total quantity
    for j in 1:nstores
        @constraint(model, x[i, j] <= row[5 + 2*j]) # Store quantity
    end
end
for i in 1:len
    @constraint(model, 100*z[i] >= x[i, 1])
end
@constraint(model, sum(z[i] for i in 1:len) <= 200)
# - CH shipping
# -- Order cost
for i in 1:nchstores_total - nchstores_weight
    @constraint(model, sum(input[k, 2*i + 4] * x[k, i] for k in 1:len) <= 
                        sum(thresholds[i, j+1] * b[i, j] for j in 1:nbuckets))
    @constraint(model, sum(input[k, 2*i + 4] * x[k, i] for k in 1:len) >= 
                        sum(thresholds[i, j] * b[i, j] for j in 1:nbuckets))
    @constraint(model, sum(b[i, j] for j in 1:nbuckets) <= 1)
end
# -- Weight cost
for i in nchstores + 1:nchstores_total
    idx = i - nchstores
    @constraint(model, sum(input[k, 5] * x[k, i] for k in 1:len) <=
                        sum(weight_limits[idx, j+1] * d[idx, j] for j in 1:nweightbuckets))
    @constraint(model, sum(input[k, 5] * x[k, i] for k in 1:len) >= 
                        sum(weight_limits[idx, j] * d[idx, j] for j in 1:nweightbuckets))

    @constraint(model, sum(d[idx, j] for j in 1:nweightbuckets) <= 1)
end
# - EU shipping
for i in nchstores_total + 1:nstores
    idx = i - nchstores_total
    @constraint(model, sum(input[k, 5] * x[k, i] for k in 1:len) <= 
                        sum(weight_limits_eu[idx, j+1] * f[idx, j] for j in 1:nweightbuckets_eu))
    @constraint(model, sum(input[k, 5] * x[k, i] for k in 1:len) >= 
                        sum(weight_limits_eu[idx, j] * f[idx, j] for j in 1:nweightbuckets_eu))

    # @constraint(model, sum(f[idx, j] for j in 1:nweightbuckets_eu) <= 1)
    @constraint(model, sum(input[j, 2*i + 4] * x[j, i] for j in 1:len) + sum(shipping_eu[idx, j]*f[idx, j] for j in 1:nweightbuckets_eu) <= 62) # Max shipping value for international stores ~ 60.-
end

# - Limit the number of different shops (optional)
@constraint(model, sum(b[i, j] for i in 1:nchstores for j in 1:nbuckets) + 
                    sum(d[i, j] for i in 1:nchstores_weight for j in 1:nweightbuckets) +
                    sum(f[i, j] for i in 1:neustores for j in 1:nweightbuckets_eu)
                    <= 4)  # <<<==== PUT LIMIT HERE

##################################
# FIRST OBJECTIVE & OPTIMISATION #
##################################
# Objective
@objective(model, Min, sum(discount*input[i, 2*j + 4] * x[i, j] for i in 1:len for j in 1:1) + # Part value (Lego.ch)
                        sum(input[i, 2*j + 4] * x[i, j] for i in 1:len for j in 2:nstores) + # Part value (other)
                        sum(shipping_eu[i, j]*f[i,j] for i in 1:neustores for j in 1:nweightbuckets_eu) + # Shipping costs (EU)
                        sum(shipping_ch[i, j]*b[i, j] for i in 1:nchstores for j in 1:nbuckets) + # Shipping costs (Fixed)
                        sum(shipping_costs[i, j]*d[i, j] for i in 1:nchstores_weight for j in 1:nweightbuckets) # Shipping costs (Weight)
                        )

# Solve & results
optimize!(model)
println(objective_value(model))

println(value(b))
println(value(d))
println(value(f))

for s in 1:nstores
    @printf("Store Nr. %i: %f\n", s, sum(value(x)[i, s] .* input[i, 2*s + 4] for i in 1:len))
end

df = DataFrame(value(x), :auto)
out = DataFrame()
out[!, "Part"] = input.part_nr
out[!, "Color"] = input.colour
for s in 1:nstores
    out[!, "Quantity"] = df[!, s]
    out[!, "Quantity"] = round.(Int, out[!,:Quantity])  # Int.(out[!,:Quantity])
    CSV.write(string("results/stores/", s, ".csv"), out)
end



# Final price
# lego, brickina, just, sta
# 92CHF 56.79 37.94 15.36 (+1USD PayPal)
# Total: 192.84 CHF



# Index of 'blue' parts
# 55, 83, 256, 260, 261, 447, 471
