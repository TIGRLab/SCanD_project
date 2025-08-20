## hold many of the scripts needed to set-up the repo for the first time..
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..

cd ${BASEDIR}

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


## nipoppy tracker init

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --bind /scratch/a/arisvoin/arisvoin/mlepage:/scratch/a/arisvoin/arisvoin/mlepage \
  containers/nipoppy.sif /bin/bash -c '
    set -e

    mkdir -p $BASEDIR/Neurobagel
    nipoppy init --bids-source $BASEDIR/data/local/bids/ $BASEDIR/Neurobagel

    NB_DIR="$BASEDIR/Neurobagel"
    BIDS_DIR="$BASEDIR/data/local/bids"

    rm -rf "$NB_DIR/pipelines/processing"/*

    first_subject=$(find "$BIDS_DIR" -maxdepth 1 -type d -name "sub-*" | head -n 1)

    if [ -d "$first_subject" ]; then
      if compgen -G "$first_subject/ses-*" > /dev/null; then
        echo "Found ses-* folder in $first_subject. Copying from nipoppy..."
        cp -r /scratch/a/arisvoin/arisvoin/mlepage/nipoppy/* "$NB_DIR/pipelines/processing"
      else
        echo "No ses-* folder in $first_subject. Copying from nipoppy_no_session..."
        cp -r /scratch/a/arisvoin/arisvoin/mlepage/nipoppy_no_session/* "$NB_DIR/pipelines/processing"
      fi
    else
      echo "No sub-* folder found in $BIDS_DIR."
    fi
  '
