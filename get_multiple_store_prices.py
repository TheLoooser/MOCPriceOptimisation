import ast
import statistics
import pandas as pd

from get_prices import map_lego_prices, extract_brickowl_data


def append_brickowl_prices(brickowl_data, parts_df, store_name):
    brickowl_data = brickowl_data.rename(
        columns={'colour_id': 'colour', 'price': f'{store_name}_price', 'amount': f'{store_name}_amount'})
    brickowl_data = brickowl_data.set_index(['part_nr', 'colour'])

    return parts_df.join(brickowl_data, on=['part_nr', 'colour'], how='left')


def extract_weight(weight):
    return statistics.fmean(list(map(float, ast.literal_eval(weight))))


if __name__ == '__main__':
    # LEGO store
    lego_html_files = ['lego200.htm', 'lego400.htm', 'lego501.htm']
    map_lego_prices(lego_html_files)

    # BrickOwl store(s)
    part_list = pd.read_csv('results/part_list_with_lego_prices.csv', header=0)

    store_html_files = [
        # CH
        'blackcat', 'swisspandabricks', 'brixxschmidt', 'brickntoast',
        'playmondo', '500tomoon', 'hochisbricks', 'jurabrick', 'welcomebricks',
        # EU
        '3_bricks', 'andreas_brickstore', 'brickina', 'brick_takeover', # 'brick_tasty',
        'brikea', 'just_brix', 'kleinesteinewelt', 'la_brickstore',
        'little_big_store', 'lo_stanzino', 'sta_laedla', 'vivid_bricks'
    ]

    for store in store_html_files:
        print(store)
        brickowl_data = extract_brickowl_data(store)
        part_list = append_brickowl_prices(brickowl_data, part_list, store)

    part_list = part_list.drop(columns=['element_ids', 'lego_ids', 'bricklink_ids', 'lego_ele_id'])
    part_list['weight'] = part_list['weight'].apply(extract_weight)
    part_list.to_csv('results/part_list_multiple_stores.csv', index=False)

    # Prepare output for optimisation
    df = pd.read_csv('results/part_list_multiple_stores.csv', header=0)
    df = df.fillna(0)
    df['available'] = df[[f'{s}_amount' for s in ['lego'] + store_html_files]].sum(axis=1)
    missing = df[df.available < df.quantity]
    print(missing.head(n=10))

    df = df[df.available >= df.quantity]
    df = df.astype({f'{s}_amount': int for s in ['lego'] + store_html_files})
    df.drop(columns=['available'], inplace=True)
    df.to_csv('results/julia_input_multiple_stores.csv', index=False)

    