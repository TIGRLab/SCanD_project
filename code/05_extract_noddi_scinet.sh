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

# Iterate over each subject
for subject in $SUBJECTS; do

    # Check if session folders exist for the subject
    SESSIONS=$(ls ${BASEDIR}/data/local/bids/${subject}/ses-* 2>/dev/null | xargs -n 1 basename || echo "")

    if [ -z "$SESSIONS" ]; then
        # No session directories found, run the script without the --session option
        singularity exec \
        -B ${BASEDIR}:/base \
        -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
        -B ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/:/noddi_dir \
        ${BASEDIR}/containers/tbss_2023-10-10.simg \
        /bin/bash << 'EOF'

        # Inside the Singularity container
        NODDI_DIR=/noddi_dir
        ENIGMA_DIR=/enigma_dir
        ENIGMA_DTI_CODES=/base/code

        # Run the Python script without the --session option
        ${ENIGMA_DTI_CODES}/extract_NODDI_enigma.py --noddi_outputdir /noddi_dir --enigma_outputdir /enigma_dir --outputdir /noddi_dir --subject ${subject}

EOF

        # Check if the execution was successful
        if [ $? -eq 0 ]; then
            echo "$subject Done !!" >> ${BASEDIR}/logs/enigma_dti.tsv
        else
            echo "$subject extract_noddi failed" >> ${BASEDIR}/logs/enigma_dti.tsv
        fi

    else
        # Iterate over each session folder found
        for session in $SESSIONS; do
            singularity exec \
            -B ${BASEDIR}:/base \
            -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
            -B ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/:/noddi_dir \
            ${BASEDIR}/containers/tbss_2023-10-10.simg \
            /bin/bash << 'EOF'

            # Inside the Singularity container
            NODDI_DIR=/noddi_dir
            ENIGMA_DIR=/enigma_dir
            ENIGMA_DTI_CODES=/base/code

            # Run the Python script with the --session option
            ${ENIGMA_DTI_CODES}/extract_NODDI_enigma.py --noddi_outputdir /noddi_dir --enigma_outputdir /enigma_dir --outputdir /noddi_dir --subject ${subject} --session ${session}

EOF

            # Check if the execution was successful
            if [ $? -eq 0 ]; then
                echo "$subject $session Done !!" >> ${BASEDIR}/logs/enigma_dti.tsv
            else
                echo "$subject $session extract_noddi failed" >> ${BASEDIR}/logs/enigma_dti.tsv
            fi
        done
    fi

done
