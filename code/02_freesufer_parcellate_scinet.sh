#!/bin/bash
#SBATCH --job-name=freesurfer
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=16:00:00


SUB_SIZE=1 ## number of subjects to run

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
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg


## setting up the output folders
export OUTPUT_DIR=${BASEDIR}/data/local/freesurfer_parcellate  # use if version of fmriprep >=20.2
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${LOGS_DIR} # ${LOCAL_FREESURFER_DIR}

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


export APPTAINERENV_FS_LICENSE=/home/freesurfer/.freesurfer.txt
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

export SUBJECTS_DIR=${BASEDIR}/data/local/freesurfer_long
export GCS_FILE_DIR=${BASEDIR}/templates/freesurfer_parcellate


singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:/li \
    -B ${SUBJECTS_DIR}:/subjects \
    -B ${GCS_FILE_DIR}:/gcs_files \
    ${SING_CONTAINER} \
    /bin/bash -c "
    GCS_FILES=(/gcs_files/*.gcs)
    
    for gcs_file in ${GCS_FILES[@]}; do
    
      mris_ca_label -l \$SUBJECTS_DIR/${SUBJECTS}/label/lh.cortex.label \
        ${SUBJECTS} lh \$SUBJECTS_DIR/${SUBJECTS}/surf/lh.sphere.reg \
        /gcs_files/lh.Schaefer2018_400Parcels_17Networks.gcs \
        \$SUBJECTS_DIR/${SUBJECTS}/label/lh.Schaefer2018_400Parcels_17Networks_order.annot
 
      mris_ca_label -l \$SUBJECTS_DIR/${SUBJECTS}/label/rh.cortex.label \
        ${SUBJECTS} rh \$SUBJECTS_DIR/${SUBJECTS}/surf/rh.sphere.reg \
        /gcs_files/rh.Schaefer2018_400Parcels_17Networks.gcs \
       \$SUBJECTS_DIR/${SUBJECTS}/label/rh.Schaefer2018_400Parcels_17Networks_order.annot
       
    done
    "

exitcode=$?


# Output results to a table
for subject in $SUBJECTS; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    freesurfer failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done
