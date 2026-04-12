import pandas as pd
import os.path


if __name__ == "__main__":
    part_list = pd.read_csv("data/CSV/rebrickable.csv")

    path = 'results/stores/'
    num_files = len([f for f in os.listdir(path)
                    if os.path.isfile(os.path.join(path, f))])
    
    print(f"Number of stores: {num_files}")
    for i in range(1, num_files + 1):
        part_list_store = pd.read_csv(os.path.join(path, str(i) + ".csv"))
        part_list = pd.merge(part_list, part_list_store, how='left', on=['Part', 'Color'], suffixes=["", f"_{i}"])

    
    part_list['selected'] = part_list.filter(like='Quantity_').sum(1)
    
    print("Parts with no or insufficient selection (or too many):")
    print(part_list[part_list['Quantity'] != part_list['selected']].head())
    print("Example of part with no selection:")
    print(part_list[(part_list['Part']=='3028') & (part_list['Color']==1)])

  

