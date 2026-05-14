# Pipeline 1: Two Stores
Compare Lego pick-a-brick piece prices to the piece prices of a BrickOwl store for a given set.
This pipeline only compares pieces available in both sets. Shipping costs are also ignored, but the custom tariffs and VAT are respected to a certain degree.

## Step 1: Complete Rebrickable parts list
Download a list of all parts of your desired set (or MOC) from rebrickable, i.e. export as Rebrickable CSV. Place the file in the `/data` folder.

## Step 2: API key
On rebrickable.com under your account settings, genereate a new API key and copy its value into the `.env` file. 
```
API_KEY=<Your API key goes here>
```
Link to the API docs: https://rebrickable.com/api/v3/docs/

## Step 3: Colour names
Get the names of the colours used in your set based on the colour id in the CSV export of the parts list from rebrickable. The resulting dictionary of the names will be stored as a JSON file in the `/results` folder. The names of the colours will be fetched via the rebrickable API. Certain colours have different names based on where you encounter them. For this reason, not only the rebrickable name of the colour is retrieved, but also the BrickOwl name.

## Step 4: Element ID's
Because part numbers are not unique, the element id (or list of element id's) is requested from rebrickable based on the combination of the part number and the colour from the complete parts list. Since these element id's from rebrickable can differ to id's seen on external sites like lego.com for example, a second API call is made for each rebrickable element id of each part to also fetch their external element id. Currently, only the element id's for lego.com are extracted.

## Step 5: LEGO pick-a-brick list
Similarly to step 1, export the list of all parts of your set as a CSV. This time, select the Lego pick-a-prick format, s.t. it can later be imported to the [Lego pick-a-brick website](https://www.lego.com/de-ch/pick-and-build/pick-a-brick). Since the website only allows you to upload 200 pieces at a time, you might have to split up your CSV into multiple files if your set consists of more than 200 different pieces.

## Step 6: LEGO pick-a-brick HTML
Upload the list(s) from the previous step to the lego pick-a-brick website and download the resulting site(s), i.e. save the page as HTML to your local computer. The local files should consist of a `.htm` file and a folder of additional files (`.js`, `.png`, `.css`, ...), which are needed to render the website. Place these files in the `/data` folder of this repository.

## Step 7: BrickOwl store HTML
On the **Buy Parts** tab under your set, MOC, parts list, etc., click on the **Add to Cart** button for the BrickOwl store where you would like to buy your lego pieces from. Then again, as in the previous step, download the HTML page of the BrickOwl shopping cart and place the files in the `/data` folder.

## Step 8: Extract data from LEGO HTML
From the LEGO HTML file extract the individual piece price, the requested amount, the element id and part number for each lego piece. The result is stored in a nested dictionary, which looks as follows.
```
dictionary
└── part nr 1
│   └── element id 1
|   |   └─ price
│   └── element id 2
|   |   └─ price
│   │   element id 3
|   |   └─ price
|   └── ...
└── part nr 2
│   └── element id 1
|   |   └─ price
|   └── ...
└── part nr 3
└── ...
```

## Step 9: Map LEGO price to rebrickable part
Using the resulting list from step 4, we check for each part if we can find a matching price in the dictionary from step 8 using the following algorithm.
``` python
1. if part number is in the keys of the dict
    2. if the element id is in the keys of the inner dict
        3. add lego price to complete parts list
4. if no match has been found 
    5. if any of the lego element id is in the keys of the dict
        2.
            3.
    6. no matching lego price was found
```
Finally, the updated parts list (with the lego prices) is stored as a `.csv` in the `/results` folder.

## Step 10: Extract data from BrickOwl HTML
Similarly as in step 8, data is extracted from the HTML file. The price and amount values can be used as they are, the part number is a bit more complicated, because it is not unique (same number for different colours). Therefore, the part number(s) are extracted from the piece description string as well as the name of the colour. Using the colour dictionary from step 3, we get the colour id of its name. Then, like in step 4, we use the part number in combination with the colour id to get the element id(s) of this piece by sending a GET request to the rebrickable API. Actually, the element id is not even used, the GET request is solely used to check whether the combination of part number and colour id is valid. If no element id could be found, we take the list from step 4 and filter it for the colour id we found earlier in this step. Looping through the remaining parts in this list, each lego element id is tested to see if it matches any of the part numbers found in the BrickOwl HTML. If a match is found, we use the associated part number instead of the part number which was extracted from the HTML file.

## Step 11: Map BrickOwl store prices to rebrickable part
With the part number and the colour id from both the updated parts list from step 10 and the recently extracted data from step 10, we can use these two values to merge the two lists together to create the final parts list containing the prices from both stores (LEGO and BrickOwl). This list is then also stored as a `.csv` file in the `/results` folder.

## Step 12: Create input file for Julia
In preparation for the optimisation, the parts list is stripped down and all the unnecessary columns are removed. The required columns include the available amounts and prices for each store as well as the total quantity for the MOC. Additionaly, in order to easier keep track of the actual part, the part number and colour are kept as well. Furthermore, pieces with quantities only available are removed from the list, because there is nothing to optimise for.

## Step 13: Optimise costs
Using the input file from the previous step, a mixed integer linear programming model is implemented in [JUmP](https://jump.dev/JuMP.jl/stable/). Variables are created the amount of pieces to be bought in each store ($x_{i}$ for the i-th piece in store x), plus a binary variable to include the shipping costs if pieces are bought from store y.  
Basically, there only exist three simple constraints
-  The total amount of pieces across the two stores for a given part has to equal the amount of pieces of the MOC.
- The amount of pieces for a given part cannot be higher than the available quantity for a shop.
- If even one piece is bought from the BrickOwl shop, we have to include the shipping costs for this store¹.

¹: It is assumed that enough pieces are bought from the lego store, such that no shipping costs are accumulated.

### 13.1
The first objective minimises the total part cost while respecting all additional costs (shipping & customs tariffs).

### 13.2
The second objective also minimises the total cost, but this time the focus solely lies on the part cost, i.e. the shipping cost and customs tariffs are ignored.

### 13.3
For the third objective a new variable and a new constraint is introduced. The goal is to split up the parts from the BrickOwl store into multiple packets, such that the customs tariffs can be avoided. This model works under the assumption that paying the shipping costs multiple times is still cheaper than the customs tariffs.

---
For the first objective, the resulting part list for the two stores are stored in two `CSV` files, which can be imported from rebrickable to create custom set lists. Parts which appear in both stores in the final solution are printed to the terminal.  
After optimising the second objective, the parts which differ to the previous solution are printed to the terminal, such that the differences can be compared.  
The output after the third objective are simply the total prices of the two stores. 


## Step 14: Interpret results
When trying to build a MOC, you start out on rebrickable. From there, the easiest way to get the parts needed to build the set would be to search for a BrickOwl shop with as many pieces (to a reasonable price) as possible and then buy the remaining pieces from the LEGO pick-a-brick shop. This will in most cases already be cheaper than buying all the pieces from LEGO directly, since the individiual part prices on BrickOwl stores tend to be slightly cheaper. To find the best value combination, this optimisation can be solved under different constraints (see previous step).

1. Assuming that we buy as many pieces as possible in one order, we inevitabely will have to pay for shipping (large packet) and customs tariffs. This solution to this model should in most cases be slightly cheaper. However, we notice that the customs tariffs are responsible for a non-neglible amount of the final costs.
2. When ignoring the customs tariffs and the shipping costs to find the cheapest possible price regardeless of additional costs, we can compare the solution to the one from the previous objective. The pieces which change store in this new solution are all slightly cheaper on BrickOwl than on LEGO, i.e. in the previous model, these pieces would have been bought from LEGO even though their individiual piece price is not lower than on the BrickOwl store.
3. Another, this time realistic, option to get rid of the customs tariffs is to force the BrickOwl packets into smaller orders.

In conclusion, the first optimisation is a neat improvement over simply buying the maximum from one shop and filling up the remaning parts from the second shop. This version will certainly already help in bringing down the total part cost, but this is definitely not the best overall solution yet. This is due to only focusing on two stores at a time and allowing for customs tariffs, which can be expensive.  
The second optimisation version only really tells you how low the costs could go in an ideal world, where there are no shipping costs or tariffs at all. This does not really help you in deciding which part to buy in which shop, but rather shows you a lower bound of the total costs of your MOC. I.e. expect the final cost to be above this value.  
The third option is an improvement over the first one, because it eliminates the customs tariffs by introducing additional shipping costs. This version only works under the assumption that paying the shipping costs multiple times is still cheaper than the customs tariffs for one larger order would have been.


> **⚠** Using the maximum available pieces from one store normally results in a higher total cost than with the optimal solution.

> **__NOTE__** As a general rule of thumb, buy pieces on BrickOwl if the price plus the prices times MWST is lower than the price on the LEGO pick-a-brick store¹.

¹: This only makes sense, if you buy large enough quantities. For smaller amounts, the shipping costs for the BrickOwl store will play a significant factor.



# Pipeline 2: Multiple stores
While we managed to cut down on the costs with the first pipeline, before we even got to verifying the selected quantities (which will be a separate step at the end of this pipeline), we noticed that we can do even better. The reason for this is twofold. One, by focusing on only two stores at a time, we exclude shops with potentially even cheaper part prices. And two, shipping costs are usually cheaper the closer the stores are to you. If you buy from stores from your own country, not only will the shipping costs be lower (although the individual part prices might be slightly higher), but also can you circumvent all the customs tariffs.  
Instead of starting a completely new pipeline, we begin by using the same first six steps and then continue with the following step.

## Step 17: Adding weights
As it turns out, using the costs of the pieces to estimate the shipping costs of a store is not accurate enough, especially since parts with similar prices can vary in weight. And because most stores operate using weights to calculate the shipping costs, it made sense to incorporate this aspect to improve the accuracy of the optimisation model. Conveniently [BrickLink](https://www.bricklink.com/catalogDownload.asp) provides a part list with the information of the individual part weight from which we can extract this value for each part in our MOC part list.
> **__NOTE__** In the optimisation model, international stores have only one weight limit to keep it simpler. International stores anyway have a given upper limit of total cost to avoid customs tariffs.

## Step 16: Extract data from BrickOwl stores
We repeat Step 7 from the previous Pipeline for as many times as we wish, i.e. for as many stores as we want to include. Then steps 8 and 9 are performed as well followed by steps 10 and 11 for all the newly added stores. Finally, an updated version of step 12 is used to create the required input of the new optimisation model. Apart from having more columns due to the additional stores, this file also now contains entries of stores which have no quantity of a given piece. Because the opimisation model has a constraint that enforces that the total required quantity is met, this difference in the input file does not matter.

## Step 17: Optimise costs (again)
The optimisation in this step uses an updated version of the Optimisation model in Step 13. The most noteable change is the inclusion of the part weigths for the shipping cost constraints. Also, an option to limit the number of stores was added.


## Step 18: Interpret results (again)
To validate the cost reduction made by this pipeline, we compare the results of the optimisation model using different versions of part list of a MOC with 501 unique parts and 2911 total pieces with different cost estimations and optimisations.

<table>
    <thead>
        <tr>
            <th tyle="border-right: 1px solid"></th>
            <th colspan=5>Estimations</th>
            <th colspan=4>Optimisations</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td style="border-right: 1px solid">Variant</td>
            <td>Rebrickable</td>
            <td>MOC Creator</td>
            <td>BrickOwl</td>
            <td>BrickOwl AutoSelect</td>
            <td style="border-right: 1px solid">BrickOwl AutoSelect (fixed⁶)</td>
            <td>Blue Parts¹</td>
            <td>Cheap Parts²</td>
            <td>No Parts³</td>
            <td>Lego discount⁷</td>
        </tr>
        <tr>
            <td style="border-right: 1px solid">Parts</td>
            <td>260.10</td>
            <td>188.60</td>
            <td>296.45</td>
            <td>142.65</td>
            <td style="border-right: 1px solid">156.06</td>
            <td>177.85</td>
            <td>177.30</td>
            <td>177.25⁴</td>
            <td>170.60</td>
        </tr>
        <tr>
            <td style="border-right: 1px solid">Shipping</td>
            <td>N/A</td>
            <td>N/A</td>
            <td>N/A</td>
            <td>39.34 (+29.25)⁵</td>
            <td style="border-right: 1px solid">61.81</td>
            <td>28.65</td>
            <td>28.60</td>
            <td>25.05</td>
            <td>25.05</td>
        </tr>
        <tr>
            <td style="border-right: 1px solid">Total</td>
            <td>>260.10</td>
            <td>>188.60</td>
            <td>>296.45</td>
            <td>~211.25</td>
            <td style="border-right: 1px solid">217.85</td>
            <td>206.50</td>
            <td>205.90</td>
            <td>202.30</td>
            <td>195.65</td>
        </tr>
    </tbody>
</table>


¹ The selected MOC contains a couple of blue pieces, which can be replaced by the same brick in any colour (since the brick will be hidden anyway). This part list contains the brick in their original colour, i.e. blue.  
² A couple of the blue bricks which can be replaced, can be found in a different colour for less money. This part list replaced some blue parts with a commonly found colour of the same brick, which is on average cheaper.  
³ This part list excludes the blue parts for the optimisation. The parts will then manually be added back (in any colour) by selecting it in any of the stores found in the solution of the optimisation.  
⁴ 174.45 for the parts and roughly 1.80 for the missing parts assuming that the shipping costs did not increase.  
⁵ 3 out of the 7 selected stores do not have shipping costs (Quote Only). The shipping costs for the remaining 4 stores is on average 9.75.  
⁶ Additionally, the minimum lot average or the minimum order for certain stores is not met. If we remove those stores and select the next best stores (with the most parts that are still needed), the final cost increases to 217.85.  
⁷ 8% discount of a vaucher of any value for lego.ch. Uses the 'no parts' part list.  

Usually, the solution to the optimisation model found by the solver consists of five stores. The Lego store is responsible for the main bulk (>= 100.-, due to no shipping costs at this point), then there are two more national stores as well as two international stores. The part costs for these stores varies from around 5.90 to 43.70. The store with the lowest part cost, still has quite high shipping costs (>10). The reason why this store is selected at all is due to some rare parts which not many stores even offer (e.g. this MOC contains one part, which only two out of the 25 had in stock).

Based on the results in the table above, we can make some observations:
- The cost estimations of the websites are quite high. 
- The cost estimations from the MOC creator for the parts is quite accurate.
- The Auto Select Feature works quite well focusing only on the part cost. However, stores with no clear shipping costs make this feature very hard to use.
- The estimated shipping costs of this solution are around 40-50% of the total cost, which seems insane.
- The fixed Auto Select Feature is the first actual solution, which shows an accurate price.
- The solution with blue parts is the first improvement. It already beats the part cost provided by the MOC creator and has a lower cost than the brickowl auto select feature.
- Replacing certain blue parts with on average cheaper colours yields another improvement, but this time it is almost irrelevant.
- Completely removing those parts from the optimisation (and manually adding them back later) results in another cost reduction, but this one should come with an asterisk, because it could be that the shipping costs increases and thus making the improvement less noticeable.
- The final optimisation with the 8% discount voucher is the most no brainer improvement and could be applied to all prior optimisations.

> **__NOTE__** A limitation of this pipeline is when a part (e.g. as the blue ones) can be in any colour. This would required to get the part price for all available colours for every shop as well as additional logic to account for this constraint in the optimisation model, since no longer all parts have to have their quantity met.

For completion's sake, we also tested the lego discount variant by limiting the number of stores to two (i.e. simulating the behaviour of the first pipeline). The solver did find a solution, which means that it is in fact possible to purchase all necessary parts of this MOC only from two different stores. However, the total cost increased to 240.30. Also, this comparison is not quite fair, because the first pipeline excluded the parts, which were not present in either store.


## Step XX: Verify quantities and prices
see verify_parts.py
created CSV's (lego, lego_only, missing, ...) -> import to rebrickable (for lego export newly created rebrickable list in the lego pick-a-brick format) -> use lists to shop in the corresponding stores -> check total price & compare to output of the scripts

for the part list with blue pieces removed, make sure these parts are available in the selected stores.

> **⚠** The price shown in the brickowl store can deviate slightly from the sum of the price of the individual pieces multiplied by the selected amount.

