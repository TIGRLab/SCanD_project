#!/bin/bash
#SBATCH --job-name=extract_to_share_stage3
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=08:00:00


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

## magetbrain, xcp, xcp-noGSR, qsirecon 

PROJECT_DIR=${SLURM_SUBMIT_DIR}


if [ -d "${PROJECT_DIR}/data/local/derivatives/xcp_d/0.7.3" ];
then

echo "copying over the xcp_d folder"

## copy over the xcp json files
rm -rf ${PROJECT_DIR}/data/share/xcp_d

## copy over the xcp  folder (all data)
rsync -a ${PROJECT_DIR}/data/local/derivatives/xcp_d  ${PROJECT_DIR}/data/share

else
    echo "No XCP_D outputs found."
fi


if [ -d "${PROJECT_DIR}/data/local/derivatives/xcp_noGSR" ];
then

echo "copying over the xcp_noGSR folder"

## copy over the xcp json files
rm -rf ${PROJECT_DIR}/data/share/xcp_noGSR

## copy over the xcp  folder (all data)
rsync -a ${PROJECT_DIR}/data/local/derivatives/xcp_noGSR  ${PROJECT_DIR}/data/share

else
    echo "No XCP_NO_GSR outputs found."
fi


