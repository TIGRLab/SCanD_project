import pandas as pd
import os
import glob

# Get list of all relevant CSV files
tay_dwi_metrics_files = glob.glob("/archive/data/TAY/pipelines/in_progress/baseline/qsiprep/**/*desc-ImageQC_dwi.csv", recursive=True)

# Function to read each CSV and add the filename (without .csv extension)
def read_and_add_filename(filepath):
    df = pd.read_csv(filepath)
    df['filename'] = os.path.basename(filepath).replace('.csv', '')
    return df

# Read all CSV files into a single dataframe
tay_dwi_metrics = pd.concat([read_and_add_filename(f) for f in tay_dwi_metrics_files], ignore_index=True)

# Separate 'filename' column into 'subject' and 'session'
tay_dwi_metrics[['subject', 'session']] = tay_dwi_metrics['filename'].str.split('_', expand=True)

# Write the combined dataframe to a new CSV file
tay_dwi_metrics.to_csv("../data/qsiprep_metrics.csv", index=False)
