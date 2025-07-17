#!/bin/bash
#SBATCH --job-name=enigma_dti
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=01:00:00

# Load necessary modules if needed
# module load python

BASEDIR=${SLURM_SUBMIT_DIR}

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


## nipoppy trackers 

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --env SUBJECTS="$SUBJECTS" \
  containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/enigmadti/0.1.1/output/
    ls -al derivatives/enigmadti/0.1.1/output/

    ln -s "$BASEDIR/data/local/data/local/enigmaDTI/" derivatives/enigmadti/0.1.1/output/ || true

    nipoppy track  --pipeline enigmadti  --pipeline-version 0.1.1 
  '
