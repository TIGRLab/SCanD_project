#!/bin/bash
#SBATCH --job-name=xcp
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=06:00:00


SUB_SIZE=2 ## number of subjects to run is 1 because there are multiple tasks/run that will run in parallel
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

export BIDS_DIR=${BASEDIR}/data/local/bids

export SING_CONTAINER=${BASEDIR}/containers/xcp_d-0.6.0.simg


## setting up the output folders
export OUTPUT_DIR=${BASEDIR}/data/local/
export FMRI_DIR=${BASEDIR}/data/local/fmriprep/

export WORK_DIR=${BASEDIR}/work/xcp
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR}

## get the subject list from a combo of the array id, the participants.tsv and the chunk size
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`
SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`




singularity run --cleanenv  ${SING_CONTAINER} \
    $FMRI_DIR\
    $OUTPUT_DIR\
    participant\
    --participant_label ${SUBJECTS} \
    -w ${WORK_DIR} \
    --cifti \
    --smoothing 0 \
    --fd-thresh 0.5 \
    --notrack

# note, if you have top-up fieldmaps than you can uncomment the last two lines of the above script

exitcode=$?

# Output results to a table
for subject in $SUBJECTS; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    xcp_d failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done

