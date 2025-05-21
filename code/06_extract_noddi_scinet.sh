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

    else
        # Iterate over each session folder found
        for session in $SESSIONS; do
            singularity exec -B ${BASEDIR}:/base \
                -B ${BASEDIR}/data/local/enigmaDTI:/enigma_dir \
                -B ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/:/noddi_dir \
                ${BASEDIR}/containers/tbss_2023-10-10.simg \
                /bin/bash -c "/base/code/extract_NODDI_enigma.py --noddi_outputdir /noddi_dir --enigma_outputdir /enigma_dir --outputdir /noddi_dir/noddi_roi --subject $subject --session $session"

        done
    fi

done


## nipoppy trackers 

cd ${BASEDIR}/Neurobagel

source ../nipoppy/bin/activate

mkdir -p derivatives/extractnoddi/0.1.1/output/
ls -al derivatives/extractnoddi/0.1.1/output/

ln -s ${BASEDIR}/data/local/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/ derivatives/extractnoddi/0.1.1/output/

nipoppy track  --pipeline extractnoddi  --pipeline-version 0.1.1
