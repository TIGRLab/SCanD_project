#!/bin/bash
#SBATCH --job-name=ciftify
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=08:00:00
#SBATCH --mem-per-cpu=6000

SUB_SIZE=1 ## number of subjects to run
CORES=40
export THREADS_PER_COMMAND=2

####----### the next bit only works IF this script is submitted from the $BASEDIR/$OPENNEURO_DS folder...

## set the second environment variable to get the base directory
BASEDIR=${SLURM_SUBMIT_DIR}

## set up a trap that will clear the ramdisk if it is not cleared
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

#trap the termination signal, and call the function 'trap_term' when
# that happens, so results may be saved.
trap "cleanup_ramdisk" TERM
module load apptainer/1.3.5

export BIDS_DIR=${BASEDIR}/data/local/bids
export SING_CONTAINER=${BASEDIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
#export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer/
export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/ciftify
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} 

SUBJECT_FOLDERS=(${SUBJECTS_DIR}/*long*)
SUBJECTS=("${SUBJECT_FOLDERS[@]##*/}")  # Just the folder names, like sub-CMH00000001_long-01

SUBJECT_INDEX=${SLURM_ARRAY_TASK_ID}
SELECTED_SUBJECT=${SUBJECTS[$SUBJECT_INDEX]}
 
singularity exec --cleanenv \
    -B ${SUBJECTS_DIR}:/freesurfer \
    -B ${OUTPUT_DIR}:/out \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    ciftify_recon_all --fs-subjects-dir /freesurfer ${SELECTED_SUBJECT} --ciftify-work-dir /out --fs-license /li

# Capture the exit status of the first command
exitcode=$?

# If the first command succeeds (exit code 0), run the second command
if [ $exitcode -eq 0 ]; then
    singularity exec --cleanenv \
        -B ${OUTPUT_DIR}:/out \
        ${SING_CONTAINER} \
        cifti_vis_recon_all subject sub-${SUBJECTS} --ciftify-work-dir /out
else
    echo "ciftify_recon_all failed with exit code $exitcode for sub-${SUBJECTS}"
fi


## nipoppy trackers 

singularity exec \
  --bind ${SCRATCH}:${SCRATCH} \
  --env SUBJECTS="$SUBJECTS" \
  containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    BASEDIR="$SCRATCH/SCanD_project"
    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/ciftify/1.3.2/output/
    ls -al derivatives/ciftify/1.3.2/output/

    ln -s "$BASEDIR/data/local/derivatives/ciftify/"* derivatives/ciftify/1.3.2/output/ || true

    SUBJECTS=$(echo "$SELECTED_SUBJECT" | cut -d'_' -f1)

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline ciftify \
        --pipeline-version 1.3.2 \
        --participant-id $subject
    done
  '
