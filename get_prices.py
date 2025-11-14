import pandas as pd
import re
import ast
import json
import time

from bs4 import BeautifulSoup
from collections import defaultdict
from tqdm import tqdm

from get_pieces_info import get_unique_piece_id


def extract_lego_data(filename):
    lego_data = []
    with open("data/" + filename, encoding="utf8") as fp:
        soup = BeautifulSoup(fp, 'lxml')

    for piece in tqdm(soup.find_all('div', {'class' : 'ElementLeaf_wrapper__G5C7D'})):
        item = ()
        for price in piece.find_all('div', {'class' : 'ElementLeaf_elementPrice__SwfmC ds-body-sm-medium'}):
            price = float(price.text[:-4].replace(",", "."))
            item = item + (price,)
        for amount in piece.find_all('input', {'class' : '_43qpxq_stepperInput _43qpxq_medium ds-label-lg-regular'}):
            amount = int(amount['value'])
            item = item + (amount,)
        for id in piece.find_all('p', {'class' : 'ElementLeaf_elementId__gY8no ds-body-xs-regular'}):
            element_id, part_nr = id.text[4:].split("/")
            item = item + (part_nr, element_id)
        lego_data.append(item)

    return lego_data


def map_lego_piece_id_to_mapping_list_id(dictionary):
    lego_prices = []
    not_found = []
    i = 0
    mapping = pd.read_csv('results/part_list_with_element_ids.csv', header=0).values.tolist()
    for idx, part_nr, _, _, _, element_list, lego_list in tqdm(mapping, total=len(mapping)):
        # print(str(idx) + " " + str(part_nr) + " " + element_list)
        found = False
        if part_nr in dictionary.keys():
            for element_id in ast.literal_eval(element_list):
                if element_id in dictionary[part_nr].keys():
                    lego_prices.append([element_id, *dictionary[part_nr][element_id]])                    
                    found = True
                    i += 1

        if not found:
            for lego_id in ast.literal_eval(lego_list):
                if lego_id in dictionary.keys():
                    for element_id in ast.literal_eval(element_list):
                        if element_id in dictionary[lego_id].keys():
                            lego_prices.append([element_id, *dictionary[lego_id][element_id]])
                            found = True
                            i += 1
            if not found:
                lego_prices.append([None, None, None])
                not_found.append([idx, part_nr, element_list])

    print(f"Number of mapped LEGO piece prices to the list {i}.")
    # print(len(lego_prices))
    # print(len(mapping))

    # Print the elements, which are not available on the LEGO store
    print('------')
    for ele in not_found:
        print(ele)

    # Store the updated mapping list
    pd.DataFrame([a + b for a,b in zip(mapping, lego_prices)],
             columns = ['idx', 'part_nr', 'colour', 'quantity',
                        'sparse', 'element_ids', 'lego_ids', 'lego_ele_id', 'lego_price', 'lego_amount']
                        ).to_csv('results/part_list_with_lego_prices.csv', index=False)


def map_lego_prices():
    # Extract necessary info from LEGO HTML pages
    lego_html_files = ["lego199.htm", "lego398.htm", "lego463.htm"]
    data = []
    for i, file in enumerate(lego_html_files):
        print(f'Processing file {i+1}/{len(lego_html_files)}...')
        data.extend(extract_lego_data(file))

    print(f"Number of distinct pieces available on LEGO: {len(data)}")

    # Store the data in a (nested) dictionary
    df = pd.DataFrame(data, columns=['price', 'amount', 'part_nr', 'element_id'])

    dictionary = defaultdict(dict)
    for t in df.itertuples():
        dictionary[t.part_nr][t.element_id] = (t.price, t.amount)

    # Map lego piece ID's to the ID's from the mapping list
    map_lego_piece_id_to_mapping_list_id(dictionary)


def extract_brickowl_data(store_name):
    with open(f"data/{store_name}.htm", encoding="utf8") as fp:
        soup = BeautifulSoup(fp, 'lxml')

    with open("results/colour_dict.json", 'r') as f:
        colour_dict = json.loads(f.read())

    out = pd.read_csv('results/part_list_with_lego_prices.csv', header=0)

    colour_names = []
    inv_colour_dict = {}
    for id, colour in colour_dict.items():
        if isinstance(colour, list):
            colour_names.extend(colour)
            for c in colour:
                inv_colour_dict[c] = id
        else:
            colour_names = colour_names + [colour]
            inv_colour_dict[colour] = id
    
    data = []
    over_one = False
    for tr in tqdm(soup.find('table', class_='data-table cart-table responsive_expand dt-table dataTable no-footer dtr-').find_all('tr')):
        item = ()
        for id in tr.find_all('td', {'class' : 'sorting_1'}):
            children = id.find_all("a" , recursive=False)
            part_nrs = re.search("(\([\d\s\/]*\)$)", children[0].text).group(0)[1:-1].replace(" ", "").split("/")  # ([\d]*\)$)
            
            longest_match = ""
            for colour in colour_names:
                if colour.lower() in children[0].text.lower():
                    if len(colour) > len(longest_match):
                        longest_match = colour

            for part_nr in part_nrs:
                element_ids = get_unique_piece_id(part_nr, inv_colour_dict[longest_match]) 
                time.sleep(1)
                if element_ids:
                    item = item + (str(part_nr), inv_colour_dict[longest_match])
                
            if not item:
                count = 0
                for _, part in out[out['colour'] == int(inv_colour_dict[longest_match])].iterrows():
                    for lego_ele_id in ast.literal_eval(part['lego_ids']):
                        if lego_ele_id in part_nrs:
                            count += 1
                            item = item + (part['part_nr'], part['colour'])
                            break
                if count > 1:
                    over_one = True

        for price in tr.find_all('span', {'class' : 'price pr'}):
            children = price.find_all("span" , recursive=False)
            piece_price = float(children[0].text)
            item = item + (piece_price,)
            break
        for amount in tr.find_all('td', {'class' : 'nowrap a-center a-center nowrap'}):
            children = amount.find_all("input" , {'class' : 'form-text qty input-medium'})
            piece_amount = int(children[0]["value"])
            item = item + (piece_amount,)

        data.append(item)
    print(f'All pieces have at most one corresponding part number: {not over_one}')
    print(f"Number of distinct pieces available on BrickOwl: {len(data)}")

    brickowl_df = pd.DataFrame(data, columns=['part_nr', 'colour_id', 'price', 'amount'])
    brickowl_df = brickowl_df.iloc[1:].astype({'part_nr': object, 'colour_id': int})

    return brickowl_df


def map_brickowl_prices(df):
    df = df.rename(columns={'colour_id': 'colour'})
    df = df.set_index(['part_nr', 'colour'])

    part_list = pd.read_csv('results/part_list_with_lego_prices.csv', header=0)

    merged = part_list.join(df, on=['part_nr', 'colour'], how='left')
    merged.to_csv('results/part_list_complete.csv', index=False)


def prepare_julia_input():
    complete = pd.read_csv('results/part_list_complete.csv', header=0)
    julia_input = complete[complete['price'].notnull() & complete['lego_price'].notnull()]
    julia_input[['lego_price', 'price', 'quantity', 'lego_amount', 'amount', 'idx', 'part_nr', 'colour']] \
        .to_csv('results/julia_input.csv', index=False)
    
    missing = complete[complete['price'].isnull() & complete['lego_price'].isnull()]
    missing[['part_nr', 'colour', 'quantity']].rename(columns={'part_nr': 'Part', 'colour': 'Color', 'quantity': 'Quantity'}) \
        .to_csv('results/missing.csv', index=False)
    
    # Prices of pieces exclusive to one store
    lego = complete[complete['price'].isnull() & complete['lego_price'].notnull()]
    brickowl = complete[complete['price'].notnull() & complete['lego_price'].isnull()]
    print(f"Price of pieces only available on LEGO: {(lego['lego_price'] * lego['quantity']).sum()}")
    print(f"Price of pieces only available on BrickOwl: {(brickowl['price'] * brickowl['amount']).sum()}")
    lego[['part_nr', 'colour', 'quantity']].rename(columns={'part_nr': 'Part', 'colour': 'Color', 'quantity': 'Quantity'}) \
        .to_csv('results/lego_only.csv', index=False)
    brickowl[['part_nr', 'colour', 'quantity']].rename(columns={'part_nr': 'Part', 'colour': 'Color', 'quantity': 'Quantity'}) \
        .to_csv('results/brickowl_only.csv', index=False)

    # Prices of pieces if maximum is bought from same store
    lego = complete[complete['lego_price'].notnull()]
    brickowl = complete[complete['price'].notnull()]
    print(f"Max price of pieces of LEGO pieces: {(lego['lego_price'] * lego['quantity']).sum()}")
    print(f"Max price of pieces of BrickOwl pieces: {(brickowl['price'] * brickowl['amount']).sum()}")

    # Prices of pieces needed to satisfy quantities if maximum available capacity is bought from store
    lego = complete[complete['quantity'] - complete['lego_amount'] > 0]
    brickowl = complete[complete['quantity'] - complete['amount'] > 0]
    print(f"Price of BrickOwl pieces to satisfy quantity: {(lego['price'] * (lego['quantity'] - lego['lego_amount'])).sum()}")
    print(f"Price of LEGO pieces to satisfy quantity: {(brickowl['lego_price'] * (brickowl['quantity'] - brickowl['amount'])).sum()}")


if __name__ == "__main__":
    # Lego Store (Pipeline 8 & 9)
    map_lego_prices()

    # BrickOwl store (Pipeline 10 & 11)
    brickowl_data_df = extract_brickowl_data('andrea')
    map_brickowl_prices(brickowl_data_df)

    # Pipeline 12
    prepare_julia_input()


# TODO
# Finish readme
# Verify that results (andrea & lego & missing) cover all parts (and quantities)
# -> in julia (before it is not possible)
# Add lusher tree MOC to the mix
# -> create new parts list in rebrickable (combine parts of both MOCs)
# -> Use these lists to calculate optimal price (do not forget additional instruction cost)

