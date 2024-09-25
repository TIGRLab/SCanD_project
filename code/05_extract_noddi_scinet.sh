#!/bin/bash
#SBATCH --job-name=extract_noddi
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=01:00:00

# Load necessary modules if needed
# module load python

BASEDIR=${SLURM_SUBMIT_DIR}

SUBJECTS=$(cut -f 1 ${BASEDIR}/data/local/bids/participants.tsv | tail -n +2)

# Iterate over each subject in SUBJECTS
for subject in $SUBJECTS; do
    echo "$subject       0" >> ${BASEDIR}/logs/enigma_dti.tsv
done

# Set environment variables
export TBSS_CONTAINER=${BASEDIR}/containers/tbss_2023-10-10.simg

# Make Python scripts executable
chmod +x ${BASEDIR}/code/extract_NODDI_enigma.py

# Execute Singularity container
singularity exec \
  -B ${BASEDIR}:/base \
  -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
  -B ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/:/noddi_dir \
  ${BASEDIR}/containers/tbss_2023-10-10.simg \
  /bin/bash << 'EOF'

# Inside the Singularity container
NODDI_DIR=/noddi_dir
ENIGMA_DIR=/enigma_dir

# Modify this to the location you cloned the repo to
ENIGMA_DTI_CODES=/base/code

# Run Python scripts
${ENIGMA_DTI_CODES}/extract_NODDI_enigma.py --noddi_outputdir /noddi_dir --enigma_outputdir /enigma_dir --outputdir /noddi_dir

EOF
