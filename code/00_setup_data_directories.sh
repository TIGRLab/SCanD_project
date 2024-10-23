## hold many of the scripts needed to set-up the repo for the first time..
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CURRENT_DIR=${PWD}

cd ${SCRIPT_DIR}/..
## i.e. makes folders and links to software in the arisvoin (CAMH) lab space
echo "making directories"
mkdir -p containers
mkdir -p data
mkdir -p data/local
mkdir -p data/local/bids
mkdir -p data/share
mkdir -p templates
mkdir -p templates/.cache
mkdir -p logs

chmod +x code/*.py

# create a random project id in a file to use for separating the work spaces across projects and runs
openssl rand -hex 6 -out project_id


## link the containers
echo "linking singularity containers"
CONTAINER_DIR=/scratch/a/arisvoin/arisvoin/mlepage/containers
ln -s ${CONTAINER_DIR}/fmriprep-23.2.3.simg containers/fmriprep-23.2.3.simg

ln -s ${CONTAINER_DIR}/mriqc-24.0.0.simg containers/mriqc-24.0.0.simg

ln -s ${CONTAINER_DIR}/qsiprep-0.22.0.sif containers/qsiprep-0.22.0.sif

ln -s ${CONTAINER_DIR}/freesurfer-7.4.1.simg containers/freesurfer-7.4.1.simg

ln -s ${CONTAINER_DIR}/xcp_d-0.7.3.simg containers/xcp_d-0.7.3.simg

ln -s ${CONTAINER_DIR}/fmriprep_ciftity-v1.3.2-2.3.3.simg containers/fmriprep_ciftity-v1.3.2-2.3.3.simg 

cp -r ${CONTAINER_DIR}/tbss_2023-10-10.simg containers/tbss_2023-10-10.simg

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


## copy in Erin's freesurfer licence
cp /scratch/a/arisvoin/arisvoin/mlepage/fs_license/license.txt templates/.freesurfer.txt


## copy in Erin's templates
echo "copying templates..this might take a bit"
scp -r /scratch/a/arisvoin/arisvoin/mlepage/templateflow templates/.cache/

cd ${CURRENT_DIR}
