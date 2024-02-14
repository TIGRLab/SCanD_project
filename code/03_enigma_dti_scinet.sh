#!/bin/bash

#SBATCH --job-name=enigma
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=10:00:00

BASEDIR=${SLURM_SUBMIT_DIR}

DTIFIT_DIR=${BASEDIR}/data/local/qsiprep/dtifit
ENIGMA_DIR=${BASEDIR}/data/local/qsiprep/enigmaDTI
TBSS_CONTAINER=${BASEDIR}/containers/tbss.simg

singularity exec \
  -B ${BASEDIR}/data/local/qsiprep/enigmaDTI:/enigma_dir \
  -B ${BASEDIR}/data/local/qsiprep/dtifit:/dtifit_dir \
  ${BASEDIR}/containers/tbss.simg \
  /bin/bash -c '
  for metric in FA MD RD AD; do
    ${BASEDIR}/code/run_group_enigma_concat.py \
    ${ENIGMA_DIR} ${metric} ${ENIGMA_DIR}/group_enigmaDTI_${metric}.csv
    ${BASEDIR}/code/run_group_qc_index.py ${ENIGMA_DIR} ${metric}skel
  done
  
  ${BASEDIR}/code/run_group_enigma_concat.py --output-nVox ${ENIGMA_DIR} FA ${ENIGMA_DIR}/group_engimaDTI_nvoxels.csv
  
  python ${BASEDIR}/code/run_group_dtifit_qc.py --debug ${DTIFIT_DIR}
  '
