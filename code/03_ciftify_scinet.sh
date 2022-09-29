#!/bin/bash
#SBATCH --job-name=ciftify
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=12:00:00


SUB_SIZE=8 ## number of subjects to run
CORES=40
export THREADS_PER_COMMAND=2

module load gnu-parallel/20191122

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
export SING_CONTAINER=${BASEDIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg


## setting up the output folders
export OUTPUT_DIR=${BASEDIR}/data/local/
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} # ${LOCAL_FREESURFER_DIR}

## get the subject list from a combo of the array id, the participants.tsv and the chunk size
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`
SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`

## set singularity environment variables that will point to the freesurfer license and the templateflow bits
# export SINGULARITYENV_TEMPLATEFLOW_HOME=/home/fmriprep/.cache/templateflow
# Make sure FS_LICENSE is defined in the container.
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SINGULARITYENV_FS_LICENSE=/.freesurfer.txt

# # Remove IsRunning files from FreeSurfer
# for subject in $SUBJECTS: do
#     find ${LOCAL_FREESURFER_DIR}/sub-$subject/ -name "*IsRunning*" -type f -delete
# done

parallel -j 8 "singularity run --cleanenv \
    -H $(mktemp -d -t wb-XXXXXXXXXX) \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:${SINGULARITYENV_FS_LICENSE} \
    ${SING_CONTAINER} \
      /bids /derived participant \
      --participant_label={} \
      --read-from-derivatives /derived \
      --fs-license ${SINGULARITYENV_FS_LICENSE} \
      --n_cpus 10" \
      ::: ${SUBJECTS}

exitcode=$?



# Output results to a table
for subject in $SUBJECTS; do
echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    $exitcode" \
      >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
done