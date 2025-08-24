#!/bin/bash
#SBATCH --job-name=extract_to_share_stage5
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=1000


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

## extract-noddi

module load apptainer/1.3.5

BASEDIR=${SLURM_SUBMIT_DIR}

if [ -d "${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI" ];
then

echo "copying over the extract_noddi folder"

rsync -a --include='noddi_roi/' --include='noddi_roi/**/' --include='noddi_roi/**/*.png' --include='noddi_roi/**/*.csv' --exclude='noddi_roi/**' \
    ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/ \
    ${BASEDIR}/data/share/amico_noddi

else

    echo "No extract_noddi outputs found."

fi

cp  ${BASEDIR}/Neurobagel/derivatives/processing_status.tsv ${BASEDIR}/data/share/
