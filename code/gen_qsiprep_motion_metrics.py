import pandas as pd
import os
import glob

# Get the SCRATCH directory
scratch_dir = os.getenv('SCRATCH')

# Expand the path with the SCRATCH directory
search_pattern = f"{scratch_dir}/SCanD_project/data/local/derivatives/qsiprep/0.22.0/qsiprep/*/*/dwi/*desc-ImageQC_dwi.csv"

# Get list of all relevant CSV files
tay_dwi_metrics_files = glob.glob(search_pattern, recursive=True)

# Function to read each CSV and add the filename (without .csv extension)
def read_and_add_filename(filepath):
    df = pd.read_csv(filepath)
    df['filename'] = os.path.basename(filepath).replace('.csv', '')
    return df

# Read all CSV files into a single DataFrame
tay_dwi_metrics = pd.concat([read_and_add_filename(f) for f in tay_dwi_metrics_files], ignore_index=True)

# Separate 'filename' column into 'subject' and 'session'
# Extract subject and session from the filename
tay_dwi_metrics['subject'] = tay_dwi_metrics['filename'].str.split('_').str[0].replace('sub-', '')
tay_dwi_metrics['session'] = tay_dwi_metrics['filename'].str.split('_').str[1].replace('ses-', '')


output_dir = f"{scratch_dir}/SCanD_project/data/local/derivatives/qsiprep/0.22.0/qsiprep"

# Write the combined DataFrame to a new CSV file
output_file = os.path.join(output_dir, "qsiprep_metrics.csv")
tay_dwi_metrics.to_csv(output_file, index=False)
