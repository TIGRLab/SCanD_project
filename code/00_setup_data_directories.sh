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
#ln -s /project/a/arisvoin/edickie/containers/fmriprep-21.0.2.simg containers/fmriprep-21.0.2.simg
ln -s /project/a/arisvoin/edickie/containers/fmriprep-20.1.1.simg containers/fmriprep-20.1.1.simg
ln -s /project/a/arisvoin/edickie/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg containers/fmriprep_ciftity-v1.3.2-2.3.3.simg

## copy in Erin's freesurfer licence
cp /scinet/course/ss2019/3/5_neuroimaging/fs_license/license.txt templates/.freesurfer.txt

## copy in Erin's templates
echo "copying templates..this might take a bit"
scp -r /project/a/arisvoin/edickie/templateflow templates/.cache/

cd ${CURRENT_DIR}
