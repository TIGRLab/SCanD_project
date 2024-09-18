import json
import csv

# Path to the JSON file
json_file_path = 'data/local/derivatives/qsiprep/0.22.0/qsiprep/dwiqc.json'

# Load JSON data from the file
with open(json_file_path, 'r') as json_file:
    data = json.load(json_file)

# Extract the list of subjects from the JSON data
subjects = data.get('subjects', [])

# Check if there are subjects in the data
if subjects:
    # Open a CSV file to write the data
    with open('output.csv', 'w', newline='') as csv_file:
        writer = csv.writer(csv_file)

        # Extract headers (keys) from the first subject dictionary
        headers = list(subjects[0].keys())
        writer.writerow(headers)  # Write header row

        # Iterate through each subject and write its values to the CSV
        for subject in subjects:
            writer.writerow([subject.get(header, '') for header in headers])  # Write row values for each subject

    print("Data has been written to output.csv")
else:
    print("No subjects found in the JSON data.")
