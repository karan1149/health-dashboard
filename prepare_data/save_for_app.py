import pandas as pd


def save_to_csv(data: pd.DataFrame, filename: str, folder: str = "./") -> None:
    """
    Saves a DataFrame to a CSV file.

    Parameters:
    - data (pd.DataFrame): The DataFrame to be saved.
    - filename (str): The name of the CSV file.
    - folder (str): The directory where the CSV file will be saved.
    """
    # Generate the full path
    full_path = f"{folder}{filename}.csv"

    # Save DataFrame to CSV
    data.to_csv(full_path, index=False)
