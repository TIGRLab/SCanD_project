## hold many of the scripts needed to set-up the repo for the first time..
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..

cd ${BASEDIR}

tsv_f="${BASEDIR}/data/local/bids/participants.tsv"

if [ ! -f "${tsv_f}" ]; then
    echo "Creating a new participants.tsv file at ${tsv_f}"
    echo 'participant_id' > "${tsv_f}"
fi

if [ ! -f "${BASEDIR}/data/local/bids/dataset_description.json" ]; then
    echo '{ "Name": "ScanD", "BIDSVersion": "1.0.2" }' > "${BASEDIR}/data/local/bids/dataset_description.json"
fi

# === Patch TotalReadoutTime into BOLD JSON sidecars (func/ and legacy root paths) ===
bold_json_found=0
while IFS= read -r -d '' file; do
    bold_json_found=1
    if ! grep -q "TotalReadoutTime" "$file"; then
        sed -i'' '$ s/}/     "TotalReadoutTime": 0.05\n}/' "$file"
        awk 'NR==FNR { count++; next } FNR==count-2 && $0 !~ /,$/ { print $0 ","; next }1' "$file" "$file" > temp.json
        mv -f temp.json "$file"
    fi
done < <(find "${BASEDIR}/data/local/bids" -name '*bold.json' -print0 2>/dev/null)

if [ "$bold_json_found" -eq 0 ]; then
    echo "No *bold.json files found under ${BASEDIR}/data/local/bids/"
fi

## check for multiple T1w files for freesurfer
find "${BASEDIR}/data/local/bids"/sub-* -type d -name "anat" | while read -r anat_dir; do
    t1_files=("$anat_dir"/*T1w*.nii.gz)
    t1_count=${#t1_files[@]}

    if [ "$t1_count" -gt 1 ]; then
        echo "⚠️ WARNING: $t1_count T1w files found in $anat_dir"
        printf '   Files:\n'
        for f in "${t1_files[@]}"; do
            echo "     - $(basename "$f")"
        done
        echo "   ➡️ Consider averaging these T1w images or removing extra ones before running FreeSurfer longitudinal."
        echo
    fi
done


## nipoppy tracker init

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SSL_CERT_FILE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
  --bind /scratch/arisvoin/mlepage/:/scratch/arisvoin/mlepage/ \
  --bind /etc/pki/ca-trust:/etc/pki/ca-trust \
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
        cp -r /scratch/arisvoin/mlepage/nipoppy/* "$NB_DIR/pipelines/processing"
      else
        echo "No ses-* folder in $first_subject. Copying from nipoppy_no_session..."
        cp -r /scratch/arisvoin/mlepage/nipoppy_no_session/* "$NB_DIR/pipelines/processing"
      fi
    else
      echo "No sub-* folder found in $BIDS_DIR."
    fi
  '
