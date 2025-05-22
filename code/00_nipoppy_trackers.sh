## hold many of the scripts needed to set-up the repo for the first time..
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CURRENT_DIR=${PWD}

cd ${SCRIPT_DIR}/..

## edit dataset_description and bold.json files in bids
echo '{ "Name": "ScanD", "BIDSVersion": "1.0.2" }' > data/local/bids/dataset_description.json
echo 'participant_id' > data/local/bids/participants.tsv

# Check if any *bold.json files exist
if ls data/local/bids/*bold.json 1> /dev/null 2>&1; then
    # Loop through each file
    for file in data/local/bids/*bold.json; do
        # Check if "TotalReadoutTime" is not already in the file
        if ! grep -q "TotalReadoutTime" "$file"; then
            # Add the "TotalReadoutTime" before the last closing brace
            sed -i'' '$ s/}/     "TotalReadoutTime": 0.05\n}/' "$file"
            
            # Add a comma to the second-to-last line if necessary
            awk 'NR==FNR { count++; next } FNR==count-2 && $0 !~ /,$/ { print $0 ","; next }1' "$file" "$file" > temp.json
            mv -f temp.json "$file"
        fi
    done
else
    echo "No *bold.json files found in data/local/bids/"
fi


## copy freesurfer licence
cp /scratch//arisvoin/shared/fs_license/license.txt templates/.freesurfer.txt


## copy templates
echo "copying templates..this might take a bit"
scp -r /scratch/arisvoin/shared/templateflow templates/.cache/

cd ${CURRENT_DIR}

## nipoppy tracker init

module load python/3.11.5
module load rust/1.85.0

virtualenv --system-site-packages nipoppy
source nipoppy/bin/activate 
pip install git+https://github.com/nipoppy/nipoppy.git@dev-catalog

mkdir ${CURRENT_DIR}/Neurobagel/
nipoppy init --bids-source data/local/bids/  Neurobagel/

rm -rf ${CURRENT_DIR}/Neurobagel/pipelines/processing/*

# Find the first sub-* folder
first_subject=$(find "${CURRENT_DIR}/data/local/bids" -maxdepth 1 -type d -name "sub-*" | head -n 1)

if [ -d "$first_subject" ]; then
    # Check if there's any ses-* folder inside the first subject
    if compgen -G "$first_subject/ses-*" > /dev/null; then
        echo "Found ses-* folder in $first_subject. Copying from nipoppy..."
        cp -r /scratch/arisvoin/shared/nipoppy/* ${CURRENT_DIR}/Neurobagel/pipelines/processing
    else
        echo "No ses-* folder in $first_subject. Copying from nipoppy_no_session..."
        cp -r /scratch/arisvoin/shared/nipoppy_no_session/* ${CURRENT_DIR}/Neurobagel/pipelines/processing
    fi
else
    echo "No sub-* folder found in $BASE_DIR."
fi
