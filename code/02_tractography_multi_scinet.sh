#!/bin/bash
#SBATCH --job-name=tractography
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=12:00:00


SUB_SIZE=1 ## number of subjects to run is 1 because there are multiple tasks/run that will run in parallel 
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

# input is BIDS_DIR this is where the data downloaded from openneuro went
export BIDS_DIR=${BASEDIR}/data/local/bids

## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export QSIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/qsiprep_0.16.0RC3.simg 

## setting up the output folders
# export OUTPUT_DIR=${BASEDIR}/data/local/fmriprep  # use if version of fmriprep >=20.2
export OUTPUT_DIR=${BASEDIR}/data/local/qsiprep # use if version of fmriprep <=20.1

export QSIPREP_DIR=${BASEDIR}/data/local/qsiprep 
export FREESURFER_DIR=${BASEDIR}/data/local/freesurfer

# export LOCAL_FREESURFER_DIR=${SCRATCH}/${STUDY}/data/derived/freesurfer-6.0.1
project_id=$(cat ${BASEDIR}/project_id)
export WORK_DIR=${BBUFFER}/SCanD/${project_id}/qsiprep
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} # ${LOCAL_FREESURFER_DIR}

bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

## set singularity environment variables that will point to the freesurfer license and the templateflow bits
# Make sure FS_LICENSE is defined in the container.
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/qsiprep --home /home/qsiprep \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${QSIPREP_DIR}:/qsiprep \
    -B ${FREESURFER_DIR}:/freesurfer \
    -B ${WORK_DIR}:/work \
    -B ${ORIG_FS_LICENSE}:/li\
    ${SING_CONTAINER} \
    /bids /derived participant \
    --participant_label ${SUBJECTS} \
    --skip_bids_validation \
    -w /work \
    --recon_only \
    --recon_input /qsiprep \
    --recon_spec mrtrix_multishell_msmt_ACT-hsvs \
    --freesurfer-input /freesurfer \
    --fs-license-file /li \
    --skip-odf-reports \
    --output-resolution 2.0 


exitcode=$?

# Output results to a table
for subject in $SUBJECTS; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    tractography failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done

