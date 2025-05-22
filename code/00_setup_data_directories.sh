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

ln -s ${CONTAINER_DIR}/freesurfer_synthstrip-2023-04-07.simg  containers/freesurfer_synthstrip-2023-04-07.simg

cp -r ${CONTAINER_DIR}/tbss_2023-10-10.simg containers/tbss_2023-10-10.simg

cp -r ${CONTAINER_DIR}/magetbrain.sif containers/magetbrain.sif


## copy freesurfer licence
cp /scratch/a/arisvoin/arisvoin/mlepage/fs_license/license.txt templates/.freesurfer.txt


## copy templates
echo "copying templates..this might take a bit"
scp -r /scratch/a/arisvoin/arisvoin/mlepage/templateflow templates/.cache/
