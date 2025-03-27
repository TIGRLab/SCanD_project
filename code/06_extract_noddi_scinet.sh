#!/bin/bash
#SBATCH --job-name=extract_noddi
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=03:00:00
#SBATCH --mem-per-cpu=1000

BASEDIR=${SLURM_SUBMIT_DIR}

# Extract subjects from the participants.tsv file
SUBJECTS=$(cut -f 1 ${BASEDIR}/data/local/bids/participants.tsv | tail -n +2)

module load apptainer/1.3.5

# Iterate over each subject
for subject in $SUBJECTS; do

    # Check if session folders exist for the subject
    SESSIONS=$(find ${BASEDIR}/data/local/bids/${subject} -maxdepth 1 -type d -name "ses-*" | xargs -n 1 basename | sed 's/^ses-//')

    if [ -z "$SESSIONS" ]; then
        # No session directories found, run the script without the --session option
        singularity exec -B ${BASEDIR}:/base \
            -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
            -B ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/:/noddi_dir \
            ${BASEDIR}/containers/tbss_2023-10-10.simg \
            /bin/bash -c "/base/code/extract_NODDI_enigma.py --noddi_outputdir /noddi_dir --enigma_outputdir /enigma_dir --outputdir /noddi_dir/noddi_roi --subject $subject"

        # Check if the execution was successful
        if [ $? -eq 0 ]; then
            echo "$subject 0" >> ${BASEDIR}/logs/extract_noddi.tsv
        else
            echo "$subject extract_noddi failed" >> ${BASEDIR}/logs/extract_noddi.tsv
        fi

    else
        # Iterate over each session folder found
        for session in $SESSIONS; do
            singularity exec -B ${BASEDIR}:/base \
                -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
                -B ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/:/noddi_dir \
                ${BASEDIR}/containers/tbss_2023-10-10.simg \
                /bin/bash -c "/base/code/extract_NODDI_enigma.py --noddi_outputdir /noddi_dir --enigma_outputdir /enigma_dir --outputdir /noddi_dir/noddi_roi --subject $subject --session $session"

            # Check if the execution was successful
            if [ $? -eq 0 ]; then
                echo "$subject $session 0" >> ${BASEDIR}/logs/extract_noddi.tsv
            else
                echo "$subject $session extract_noddi failed" >> ${BASEDIR}/logs/extract_noddi.tsv
            fi
        done
    fi

done
