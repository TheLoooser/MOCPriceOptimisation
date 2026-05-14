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
input = CSV.read("results/julia_input_multiple_stores_no_parts.csv", DataFrame)
shipping_ch = [
    7.5 8.5 0;  # Lego
    3.5 3.5 3.5;  # BlackCat
    # 3 6.4 15.5;  # SwissBrickBank x Panda Bricks
    # 3.2 8 8;  # Playmondo
    # 4.5 9 9;  # 500 to moon
    # 3.7 8.5 8.5;  # Swiss Brickshop
    # 4.9 0 0;  # Briques 48
]
shipping_costs = [
    3.0 4.5 6.4 13.9 20.9;
    3.5 9.0 12.0 21.0 21.0;
    3.0 3.4 9.0 12.0 15.0;
    #5.0 5.4 11.0 12.0 21.0; # Pauschale für Bearbeitungsgebühr 2.- CHF (bis 50.-)
    3.8 6.3 13.1 16.1 25.1;
    1.8 2.7 3.2 8.0 8.0;
    4.5 9.0 15.0 15 15.0;
    3.0 5.4 10.5 13.5 13.5;
    #3.2 3.7 8.5 11.5 11.5;
    6.5 9.0 12.0 12.0 12.0;
    2.95 4.95 10.5 13.5 13.5;
]
weight_limits = [
    0 65 100 320 1700 10000;  # SwissBrickBank x Panda Bricks
    0 40 1600 8500 10000 20000; # Brixx-Shop-Schmidt
    0 60 400 960 1800 10000; # Brick'n'Toast
    #0 20 390 1800 9400 10000; # K_K Bricks and Toys
    0 80 200 1500 8000 10000; # Brickunion
    0 90 140 250 2000 10000;  # Playmondo
    0 230 2000 10000 10000 10000;  # 500tomoon
    0 60 420 1800 9500 10000; # HochisBricks
    #0 80 200 2000 10000 10000;  # Swiss BrickShop
    0 930 1850 9000 10000 10000; # Jura-Bricks
    0 200 500 1250 9000 9000; # welcomebricks
]
shipping_eu = [
    10.12, # 3 Bricks
    11.21, # Andrea - up to 33.-, then 12.37 up to 40
    9.75, # Brickina
    10.63, # Brick Takeover
    8.93, # BrickTasty
    12.38, # Brikea
    15.63, # Brixitaly
    14.63, # JustBrix - up to 44.-
    8.27, # kleinesteinewelt - up to 20.-, then 27.6
    10.11, # LA_Brickstore
    12.01, # Little Big Store - up to 30.20, then 17.6 up to 43.-
    9.85, # Lo Stanzino - up to 40, then 11.32
    10.12, # Stalaedla
    11.5, # Vividbricks
    ]
shipping_limits = [
    60, 40, 60, 60, 60, 60, 60,
    44, 20, 60, 30.2, 60, 60, 60
]
thresholds = [
    0 50 100 100000;
    0 0 0 100000;
    # 0 10 70 100000;
    # 0 20 100 100000;
    # 0 18 100 100000;
    # 0 12 100 100000;
    # 0 200 100000 100000;
]
discount = 0.92

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
@variable(model, e[1:neustores], binary=true)  # 1 if pieces are bought from store i, 0 otherwise
@variable(model, d[1:nchstores_weight, 1:nweightbuckets], binary=true)

# Constraints
# - Quantities
for (i, row) in enumerate( eachrow( input ) ) 
    @constraint(model, sum(x[i, j] for j in 1:nstores) >= row[4]) # Total quantity
    for j in 1:nstores
        @constraint(model, x[i, j] <= row[5 + 2*j]) # Store quantity
    end
end
# - EU shipping
for j in nchstores_total + 1:nstores
    idx = j - nchstores_total
    @constraint(model, sum(input[i, 2*j + 4]*x[i, j] for i in 1:len) <= 
        (shipping_limits[idx] - shipping_eu[idx])*c[idx]) # Max shipping cost
end
for i in 1:neustores
    @constraint(model, c[i] <= 10000 * e[i])  # basically e[i] = c[i]/c[i] if c[i] > 0, 0 otherwise
end
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
# - Limit the number of different shops (optional)
@constraint(model, sum(b[i, j] for i in 1:nchstores for j in 1:nbuckets) + 
                    sum(d[i, j] for i in 1:nchstores_weight for j in 1:nweightbuckets) +
                    sum(e[i] for i in 1:neustores) <= nstores)  # <<<==== PUT LIMIT HERE

##################################
# FIRST OBJECTIVE & OPTIMISATION #
##################################
# Objective
@objective(model, Min, sum(discount*input[i, 2*j + 4] * x[i, j] for i in 1:len for j in 1:1) + # LEGO.ch
                        sum(input[i, 2*j + 4] * x[i, j] for i in 1:len for j in 2:nstores) +
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



# TODO
# Check why number of mapped lego pieces (lego.ch) is lower than number of available pieces
# Finish readme
# Use up to date part list from stores



# Index of 'blue' parts
# 55, 83, 256, 260, 261, 447, 471
