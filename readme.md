# Pipeline
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







TODO: Markdeep for pipeline image https://casual-effects.com/markdeep/#api