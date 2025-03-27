#!/bin/bash
#SBATCH --job-name=enigma_dti
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=1000

# Load necessary modules if needed
# module load python

BASEDIR=${SLURM_SUBMIT_DIR}

SUBJECTS=$(cut -f 1 ${BASEDIR}/data/local/bids/participants.tsv | tail -n +2)

# Iterate over each subject in SUBJECTS
for subject in $SUBJECTS; do
    echo "$subject       0" >> ${BASEDIR}/logs/enigma_dti.tsv
done

module load apptainer/1.3.5

# Set environment variables
export DTIFIT_DIR=${BASEDIR}/data/local/dtifit
export ENIGMA_DIR=${BASEDIR}/data/local/enigmaDTI
export TBSS_CONTAINER=${BASEDIR}/containers/tbss_2023-10-10.simg

# Make Python scripts executable
chmod +x ${BASEDIR}/code/run_group_dtifit_qc.py
chmod +x ${BASEDIR}/code/run_group_enigma_concat.py
chmod +x ${BASEDIR}/code/run_group_qc_index.py

# Execute Singularity container
singularity exec \
  -B ${BASEDIR}:/base \
  -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
  -B ${BASEDIR}/data/local/dtifit:/dtifit_dir \
  ${BASEDIR}/containers/tbss_2023-10-10.simg \
  /bin/bash << 'EOF'

# Inside the Singularity container
DTIFIT_DIR=/dtifit_dir
OUT_DIR=/enigma_dir

# Modify this to the location you cloned the repo to
ENIGMA_DTI_CODES=/base/code

# Run Python scripts
for metric in FA MD RD AD; do
  ${ENIGMA_DTI_CODES}/run_group_enigma_concat.py \
    ${OUT_DIR} ${metric} ${OUT_DIR}/group_enigmaDTI_${metric}.csv
  ${ENIGMA_DTI_CODES}/run_group_qc_index.py ${OUT_DIR} ${metric}skel
done

${ENIGMA_DTI_CODES}/run_group_enigma_concat.py --output-nVox \
  ${OUT_DIR} FA ${OUT_DIR}/group_engimaDTI_nvoxels.csv

${ENIGMA_DTI_CODES}/run_group_dtifit_qc.py --debug /dtifit_dir

EOF
