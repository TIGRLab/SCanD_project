#!/bin/bash
#SBATCH --job-name=mriqc
#SBATCH --output=logs/mriqc%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=80
#SBATCH --time=18:00:00


SUB_SIZE=4 ## number of subjects to run
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

# input is BIDS_DIR this is where the data downloaded from openneuro went
export BIDS_DIR=${BASEDIR}/data/local/bids

## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/mriqc-24.0.0.simg


## setting up the output folders
# export OUTPUT_DIR=${BASEDIR}/data/local/fmriprep  # use if version of fmriprep >=20.2
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/mriqc/24.0.0 # use if version of fmriprep <=20.1


project_id=$(cat ${BASEDIR}/project_id)
export WORK_DIR=${BBUFFER}/SCanD/${project_id}/mriqc
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} # ${LOCAL_FREESURFER_DIR}

## get the subject list from a combo of the array id, the participants.tsv and the chunk size

bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi




singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/mriqc --home /home/mriqc \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    ${SING_CONTAINER} \
    /bids /derived participant \
    --participant-label ${SUBJECTS} \
    -w /work \
    --nprocs 12 \
    --ants-nthreads 8 \
    --verbose-reports \
    --ica \
    --mem_gb 12 \
    --no-sub

exitcode=$?

 
# Output results to a table
for subject in $SUBJECTS; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    mriqc failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done
