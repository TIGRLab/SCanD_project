## hold many of the scripts needed to set-up the repo for the first time..
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# ----------- Color codes ------------
RED='\033[0;31m'
NC='\033[0m' # No Color
YELLOW='\033[1;33m'

# === Logging Setup ===
timestamp=$(date +"%Y%m%d_%H%M%S")

# === Get the root of the SCanD_project repo ===
ROOT_DIR=$(dirname "$SCRIPT_DIR")
echo "🔧 Starting script at $(date)"
echo "🔧 ROOT_DIR          : $ROOT_DIR"

# === Define TSV path ===
tsv_f="${ROOT_DIR}/data/local/bids/participants.tsv"

# === Create participants.tsv if not already exist ===
if [ ! -f "${tsv_f}" ]; then
    echo "Creating a new participants.tsv file at ${tsv_f}"
    echo 'participant_id' > "${tsv_f}"
fi

echo '{ "Name": "ScanD", "BIDSVersion": "1.0.2" }' > ${ROOT_DIR}/data/local/bids/dataset_description.json

# === Check if any *bold.json files exist ===
if ls ${ROOT_DIR}/data/local/bids/*bold.json 1> /dev/null 2>&1; then
    # Loop through each file
    for file in ${ROOT_DIR}/data/local/bids/*bold.json; do
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
    echo -e "${YELLOW}WARNING: ${NC} No bold.json files found in ${ROOT_DIR}/data/local/bids/"
fi

# === nipoppy tracker init ===
module load apptainer/1.3.4
export APPTAINERENV_ROOT_DIR=$ROOT_DIR

singularity exec \
  --bind ${ROOT_DIR}:${ROOT_DIR} \
  --bind /scratch/arisvoin/shared:/scratch/arisvoin/shared \
  ${ROOT_DIR}/containers/nipoppy.sif /bin/bash -c '
    set -e
    mkdir -p $ROOT_DIR/Neurobagel
    unset SSL_CERT_FILE
    nipoppy init --bids-source $ROOT_DIR/data/local/bids/ $ROOT_DIR/Neurobagel

    NB_DIR="$ROOT_DIR/Neurobagel"
    BIDS_DIR="$ROOT_DIR/data/local/bids"

    rm -rf "$NB_DIR/pipelines/processing"/*

    first_subject=$(find "$BIDS_DIR" -maxdepth 1 -type d -name "sub-*" | head -n 1)

    if [ -d "$first_subject" ]; then
      if compgen -G "$first_subject/ses-*" > /dev/null; then
        echo "Found ses-* folder in $first_subject. Copying from nipoppy..."
        cp -r /scratch/arisvoin/shared/nipoppy/* "$NB_DIR/pipelines/processing"
      else
        echo "No ses-* folder in $first_subject. Copying from nipoppy_no_session..."
        cp -r /scratch/arisvoin/shared/nipoppy_no_session/* "$NB_DIR/pipelines/processing"
      fi
    else
      echo "No sub-* folder found in $BIDS_DIR."
    fi
  '
unset APPTAINERENV_ROOT_DIR
