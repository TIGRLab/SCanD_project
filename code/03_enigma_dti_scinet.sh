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

singularity exec -H ${BASEDIR}/tmp \
  -B $PROJECT/ENIGMA_DTI_BIDS \
  -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
  -B ${BASEDIR}/data/local/dtifit:/dtifit_dir \
  ${BASEDIR}/containers/tbss2.simg \
  /bin/bash

DTIFIT_DIR=/dtifit_dir
OUT_DIR=/enigma_dir

# modify this to the location you cloned the repo to
ENIGMA_DTI_BIDS=/opt/ENIGMA_DTI_BIDS
ENIGMA_DTI_BIDS=$PROJECT/ENIGMA_DTI_BIDS

for metric in FA MD RD AD; do
${BASEDIR}/code/run_group_enigma_concat.py \
  ${OUT_DIR} ${metric} ${OUT_DIR}/group_enigmaDTI_${metric}.csv
${BASEDIR}/code/run_group_qc_index.py ${OUT_DIR} ${metric}skel
done

${BASEDIR}/code/run_group_enigma_concat.py --output-nVox \a
  ${OUT_DIR} FA ${OUT_DIR}/group_engimaDTI_nvoxels.csv

python ${BASEDIR}/code/run_group_dtifit_qc.py --debug /dtifit_dir
