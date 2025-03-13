#!/bin/bash
#SBATCH --job-name=freesurfer-synthstrip
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=08:00:00
#SBATCH --mem-per-cpu=8000

SUB_SIZE=1 ## number of subjects to run
export THREADS_PER_COMMAND=2


## set the second environment variable to get the base directory
BASEDIR=${SLURM_SUBMIT_DIR}
echo $BASEDIR

## set up a trap that will clear the ramdisk if it is not cleared
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

module load apptainer/1.3.5

#trap the termination signal, and call the function 'trap_term' when
# that happens, so results may be saved.
trap "cleanup_ramdisk" TERM

# input BIDS directory
export BIDS_DIR=${BASEDIR}/data/local/bids
export SING_CONTAINER=${BASEDIR}/containers/freesurfer_synthstrip-2023-04-07-13544feabd91.simg

## get the subject list from a combo of the array id, the participants.tsv and the chunk size

bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/^(sub-\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/^(sub-\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

echo "Running ${SUBJECTS} and slurm_array_task_ID ${SLURM_ARRAY_TASK_ID}..."

# setting up the input and output folders
export SOURCE_DATA=${BIDS_DIR}/sourcedata/freesurfer_synthstrip
export masks_dir=${SOURCE_DATA}/masks
export WORK_DIR=${SCRATCH}/SCanD/freesurfer_synthstrip/${SUBJECTS}
export LOGS_DIR=${BASEDIR}/logs

mkdir -vp ${masks_dir} ${WORK_DIR} # ${LOCAL_FREESURFER_DIR}

# Find all session directories for the subject
export sessions=$(find ${BIDS_DIR}/${SUBJECTS} -type d -name "ses-*" -exec basename {} \;)
for session in ${sessions};do

    dwi_files=$(find ${BIDS_DIR}/${SUBJECTS}/${session}/dwi -type f -name "*dwi.nii.gz" -exec basename {} \;)
    for f in ${dwi_files};do
        # Create new filename with "_nostrip"
        new_name="${f%.nii.gz}_nostrip.nii.gz"
        b="${f%.nii.gz}"  # Extract base name without extension

        # Rsync to source data while preserving structure
	    echo "Copying ${SUBJECTS} dwi data to sourcedata directory..."
        rsync -avR "${BIDS_DIR}/./${SUBJECTS}/${session}/dwi/${f}" "${SOURCE_DATA}/"

        # Rename the copied file
	    mv -v "${SOURCE_DATA}/${SUBJECTS}/${session}/dwi/${f}" "${SOURCE_DATA}/${SUBJECTS}/${session}/dwi/${new_name}"

        # Run Singularity
	    echo "Running skullstrip for ${SUBJECTS}..."
	    echo ${f}
        singularity run --cleanenv \
	    -B ${BASEDIR}/templates:/home/freesurfer_synthstrip --home /home/freesurfer_synthstrip \
        -B ${BIDS_DIR}/${SUBJECTS}/${session}/dwi:/dwi \
        -B ${masks_dir}:/masks \
	    -B ${WORK_DIR}:/work \
        ${SING_CONTAINER} \
        -i /dwi/${f} \
        -o /dwi/${f} \
        -m /masks/${b}_mask.nii.gz

        exitcode=$?
        # Log results
        if [ $exitcode -eq 0 ]; then
            echo "${SUBJECTS}   ${SLURM_ARRAY_TASK_ID} ${session}    0" \
                >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
        else
            echo "${SUBJECTS}   ${SLURM_ARRAY_TASK_ID} ${session}   singularity failed" \
                >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
        fi
    done
done
