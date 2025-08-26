#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..

cd ${BASEDIR}

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

## link the containers
echo "linking singularity containers"
CONTAINER_DIR=/scratch/arisvoin/shared/containers
ln -s ${CONTAINER_DIR}/fmriprep-23.2.3.simg containers/fmriprep-23.2.3.simg

ln -s ${CONTAINER_DIR}/mriqc-24.0.0.simg containers/mriqc-24.0.0.simg

ln -s ${CONTAINER_DIR}/qsiprep-0.22.0.sif containers/qsiprep-0.22.0.sif

ln -s ${CONTAINER_DIR}/freesurfer-7.4.1.simg containers/freesurfer-7.4.1.simg

ln -s ${CONTAINER_DIR}/xcp_d-0.7.3.simg containers/xcp_d-0.7.3.simg

ln -s ${CONTAINER_DIR}/fmriprep_ciftity-v1.3.2-2.3.3.simg containers/fmriprep_ciftity-v1.3.2-2.3.3.simg 

cp -r ${CONTAINER_DIR}/tbss_2023-10-10.simg containers/tbss_2023-10-10.simg

cp -r ${CONTAINER_DIR}/magetbrain.sif  containers/magetbrain.sif

ln -s ${CONTAINER_DIR}/nipoppy.sif  containers/nipoppy.sif


## copy freesurfer licence
cp /scratch//arisvoin/shared/fs_license/license.txt templates/.freesurfer.txt


## copy templates
echo "copying templates..this might take a bit"
scp -r /scratch/arisvoin/shared/templateflow templates/.cache/

## check for multiple T1w files for freesurfer
find "$BASEDIR/data/local/bids"/sub-* -type d -name "anat" | while read -r anat_dir; do
    t1_count=$(ls "$anat_dir"/*T1w*.nii.gz 2>/dev/null | wc -l)
    if [ "$t1_count" -gt 1 ]; then
        echo "⚠️ WARNING: $t1_count T1w files found in $anat_dir"
    fi
done

