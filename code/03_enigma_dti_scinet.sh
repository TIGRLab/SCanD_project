#!/bin/bash
#SBATCH --job-name=enigma
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=10:00:00

# Built from https://hub.docker.com/repository/docker/salimmansour/tbss/general

DTIFIT_DIR=OUTPUT_DIR=${BASEDIR}/data/local/dtifit
ENIGMA_DIR=OUTPUT_DIR=${BASEDIR}/data/local/enigmaDTI
TBSS_CONTAINER=${BASEDIR}/containers/tbss2.simg
ENIGMA_SCRIPT=/project/a/arisvoin/smansour/SPINS/SPINS_enigmaDTI/code/enigma_group.sh

singularity exec -H /project/a/arisvoin/smansour/SPASD/SPASD_enigmaDTI/tmp \
  -B $PROJECT/ENIGMA_DTI_BIDS \
  -B /project/a/arisvoin/smansour/SPASD/SPASD_enigmaDTI/data/enigmaDTI:/enigma_dir \
  -B /project/a/arisvoin/smansour/SPASD/SPASD_enigmaDTI/data/dtifit:/dtifit_dir \
  /scratch/a/arisvoin/smansour/SCanD_SPINS/containers/tbss2.simg \
  /bin/bash

DTIFIT_DIR=/dtifit_dir
OUT_DIR=/enigma_dir

# modify this to the location you cloned the repo to
ENIGMA_DTI_BIDS=/opt/ENIGMA_DTI_BIDS
ENIGMA_DTI_BIDS=$PROJECT/ENIGMA_DTI_BIDS

for metric in FA MD RD AD; do
${ENIGMA_DTI_BIDS}/run_group_enigma_concat.py \
  ${OUT_DIR} ${metric} ${OUT_DIR}/group_enigmaDTI_${metric}.csv
${ENIGMA_DTI_BIDS}/run_group_qc_index.py ${OUT_DIR} ${metric}skel
done

${ENIGMA_DTI_BIDS}/run_group_enigma_concat.py --output-nVox \a
  ${OUT_DIR} FA ${OUT_DIR}/group_engimaDTI_nvoxels.csv

python ${ENIGMA_DTI_BIDS}/run_group_dtifit_qc.py --debug /dtifit_dir
