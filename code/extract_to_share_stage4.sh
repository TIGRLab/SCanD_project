#!/bin/bash
#SBATCH --job-name=extract_to_share_stage4
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=1000



# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

## enigma_dti

module load apptainer/1.3.5

BASEDIR=${SLURM_SUBMIT_DIR}


## copy over the enigmaDTI files
if [ -d "${BASEDIR}/data/local/enigmaDTI" ];
then
echo "copying over the enigmaDTI files"
mkdir ${BASEDIR}/data/share/enigmaDTI
rsync -a ${BASEDIR}/data/local/enigmaDTI/group*  ${BASEDIR}/data/share/enigmaDTI
rsync -a ${BASEDIR}/data/local/enigmaDTI/*.html  ${BASEDIR}/data/share/enigmaDTI

rsync -a --include "*/" --include "*.png" --exclude "*" ${BASEDIR}/data/local/enigmaDTI/ ${BASEDIR}/data/share/enigmaDTI

else

    echo "No enigma_dti outputs found."

fi
