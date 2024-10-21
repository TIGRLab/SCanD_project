#!/bin/bash
#SBATCH --job-name=ciftify
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=03:00:00


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

export BIDS_DIR=${BASEDIR}/data/local/bids
export SING_CONTAINER=${BASEDIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
#export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer/
export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/ciftify
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} 


## get the subject list from a combo of the array id, the participants.tsv and the chunk 
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

 
singularity exec --cleanenv \
    -B ${SUBJECTS_DIR}:/freesurfer \
    -B ${OUTPUT_DIR}:/out \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    ciftify_recon_all --fs-subjects-dir /freesurfer sub-${SUBJECTS} --ciftify-work-dir /out --fs-license /li

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

# Log results
for subject in $SUBJECTS; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    ciftify failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done
