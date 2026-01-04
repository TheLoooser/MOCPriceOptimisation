import os
import ast
import json
import time
from tqdm import tqdm
import requests
import pandas as pd

from dotenv import load_dotenv

load_dotenv()


API_KEY = os.getenv('API_KEY')
URL = 'https://rebrickable.com/api/v3/lego/'


def get_all_parts():
    df = pd.read_csv('data/CSV/rebrickable.csv', header=0)
    df.drop(columns=['Is Spare'], inplace=True)
    return df


def get_unique_piece_id(part_nr, colour_id):
    result = requests.get(URL + f'parts/{part_nr}/colors/{colour_id}', headers={'Authorization': 'key ' + API_KEY})
    if result.status_code == 200:
        # print(str(part_nr) + ", " + str(colour_id) , result.json()['elements'])
        return result.json()['elements']
    else:
        # print(str(part_nr) + ", " + str(colour_id) , result.status_code)
        return []
    

def get_external_piece_ids(element_id):
    result = requests.get(URL + f'elements/{element_id}/', headers={'Authorization': 'key ' + API_KEY})
    if result.status_code == 200:
        # print(str(element_id) + ", " , result.json()['part']['external_ids']['LEGO'])
        return result.json()['part']['external_ids']
    else:
        # print(str(element_id) + ", " + str(result.status_code))
        return []
    

def map_element_ids_to_part_nr(element_ids):
    df = get_all_parts()
    elementid_df = pd.DataFrame(element_ids, columns=['Part', 'Color', 'ElementIDs', 'LegoIDs', 'BrickLinkIDs'])
    df = df.merge(elementid_df, how='left', left_on=['Part', 'Color'], right_on=['Part', 'Color'])
    df.to_csv('results/part_list_with_element_ids.csv')


def get_element_ids():
    print('\033[96m' + 'Getting the element id\'s of all part numbers...' + '\033[0m')
    parts_list = get_all_parts()

    element_ids = []
    for part, colour in tqdm(zip(parts_list.Part, parts_list.Color), total=len(parts_list)):
        elements = get_unique_piece_id(part, colour)
        time.sleep(1)
        lego_ids = []
        bricklink_ids = []
        for element in elements:
            external_ids = get_external_piece_ids(element)
            lego_ids.append(external_ids['LEGO'])
            bricklink_ids.append(external_ids['BrickLink'])
            time.sleep(1)
        lego_ids = list(set([x for sublist in lego_ids for x in sublist]))
        bricklink_ids = list(set([x for sublist in bricklink_ids for x in sublist]))
        element_ids.append([part, colour, elements, lego_ids, bricklink_ids])

    return element_ids

def get_weight(list_of_ids, weights):
    l = []
    for id in ast.literal_eval(list_of_ids):
        if id in weights: 
            l = l + [weights[id]]
    return l

def add_weights():
    weights = pd.read_csv('data/CSV/Parts.csv', sep='\t')
    mapping = dict(zip(weights['Number'], weights['Weight (in Grams)']))

    parts_list = pd.read_csv('results/part_list_with_element_ids.csv', header=0)
    parts_list['weight'] = parts_list['BrickLinkIDs'].apply(get_weight, weights=mapping)
    parts_list.to_csv('results/part_list_with_weights.csv', index=False)


def get_colour_name_dict():
    print('\033[96m' + 'Getting the names of all used colours...' + '\033[0m')
    colour_id_list = get_all_parts()['Color'].unique()
    colour_names = {}
    for colour_id in tqdm(colour_id_list.tolist()):
        result = requests.get(URL + f'colors/{colour_id}', headers={'Authorization': 'key ' + API_KEY})
        if result.status_code == 200:
            name, brickowl = result.json()['name'], result.json()["external_ids"]["BrickOwl"]["ext_descrs"][0][0]
            if name != brickowl:
                colour_names[colour_id] = (name, brickowl)
            else:
                colour_names[colour_id] = (name)
        time.sleep(1)
        
    with open('results/colour_dict.json', 'w') as f:
        json.dump(colour_names, f)


if __name__ == "__main__":
    # Pipeline 3
    colour_names = get_colour_name_dict()
    
    # Pipeline 4
    element_ids_list = get_element_ids()
    map_element_ids_to_part_nr(element_ids_list)

    # Pipeline ?? (adding weights)
    add_weights()

