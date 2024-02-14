## hold many of the scripts needed to set-up the repo for the first time..
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CURRENT_DIR=${PWD}

cd ${SCRIPT_DIR}/..
## i.e. makes folders and links to software in the arisvoin (CAMH) lab space
echo "making directories"
mkdir -p containers
mkdir -p data
mkdir -p data/local
mkdir -p data/share
mkdir -p templates
mkdir -p templates/.cache
mkdir -p logs

## link the containers
echo "linking singularity containers"
CONTAINER_DIR=/scinet/course/ss2019/3/5_neuroimaging/containers
ln -s ${CONTAINER_DIR}/fmriprep-20.2.7.simg containers/fmriprep-20.2.7.simg
ln -s ${CONTAINER_DIR}/mriqc-22.0.6.simg containers/mriqc-22.0.6.simg 
ln -s ${CONTAINER_DIR}/qsiprep_0.16.0RC3.simg containers/qsiprep_0.16.0RC3.simg 
ln -s ${CONTAINER_DIR}/xcp_d-0.6.0.simg containers/xcp_d-0.6.0.simg
ln -s ${CONTAINER_DIR}/fmriprep_ciftity-v1.3.2-2.3.3.simg containers/fmriprep_ciftity-v1.3.2-2.3.3.simg 
ln -s ${CONTAINER_DIR}/tbss.simg containers/tbss.simg


## copy in Erin's freesurfer licence
cp /scinet/course/ss2019/3/5_neuroimaging/fs_license/license.txt templates/.freesurfer.txt


## copy in Erin's templates
echo "copying templates..this might take a bit"
scp -r /scinet/course/ss2019/3/5_neuroimaging/templateflow templates/.cache/

cd ${CURRENT_DIR}
