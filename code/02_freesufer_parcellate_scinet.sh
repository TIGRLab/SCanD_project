#!/bin/bash
#SBATCH --job-name=freesurfer_parcellate
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=1:00:00

SUB_SIZE=1  # Number of subjects to run per job

# Set BASEDIR to the submission directory
BASEDIR=${SLURM_SUBMIT_DIR}

# Cleanup function to clear the ramdisk
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

trap "cleanup_ramdisk" TERM

# Set environment variables
export BIDS_DIR=${BASEDIR}/data/local/bids
export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export OUTPUT_DIR=${BASEDIR}/data/local/freesurfer_parcellate
export LOGS_DIR=${BASEDIR}/logs
export APPTAINERENV_FS_LICENSE=/home/freesurfer/.freesurfer.txt
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SUBJECTS_DIR=${BASEDIR}/data/local/freesurfer
export GCS_FILE_DIR=${BASEDIR}/templates/freesurfer_parcellate

# Create necessary directories
mkdir -vp ${OUTPUT_DIR} ${LOGS_DIR}

# Calculate subject list for this job array
N_SUBJECTS=$(( $(wc -l < ${BIDS_DIR}/participants.tsv) - 1 ))
bigger_bit=$(( (SLURM_ARRAY_TASK_ID + 1) * SUB_SIZE ))
array_job_length=$(( N_SUBJECTS / SUB_SIZE ))
Tail=$(( N_SUBJECTS - (array_job_length * SUB_SIZE) ))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=$(sed -n -E 's/sub-(\S*)\>.*/\1/gp' ${BIDS_DIR}/participants.tsv | head -n ${N_SUBJECTS} | tail -n ${Tail})
else
    SUBJECTS=$(sed -n -E 's/sub-(\S*)\>.*/\1/gp' ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE})
fi

# Run Python script passing SUBJECTS as arguments
python -c "
import subprocess

for subject in $SUBJECTS; do
    subprocess.run([
        'singularity', 'run', '--cleanenv',
        '-B', f'{BASEDIR}/templates:/home/freesurfer', '--home', '/home/freesurfer',
        '-B', f'{BIDS_DIR}:/bids',
        '-B', f'{OUTPUT_DIR}:/derived',
        '-B', f'{ORIG_FS_LICENSE}:/li',
        '-B', f'{SUBJECTS_DIR}:/subjects',
        '-B', f'{GCS_FILE_DIR}:/gcs_files',
        SING_CONTAINER,
        '/bin/bash', '-c',
        '''
export SUBJECTS_DIR=/subjects

# List all lh and rh GCS files in the directory
LH_GCS_FILES=(/gcs_files/lh.*.gcs)
RH_GCS_FILES=(/gcs_files/rh.*.gcs)

    for lh_gcs_file in $LH_GCS_FILES; do
        base_name=$(basename "$lh_gcs_file" .gcs)
        mris_ca_label -l "$SUBJECTS_DIR/sub-$subject/label/lh.cortex.label" \
            "$subject" lh "$SUBJECTS_DIR/sub-$subject/surf/lh.sphere.reg" \
            "$lh_gcs_file" \
            "$SUBJECTS_DIR/sub-$subject/label/${base_name}_order.annot"
    done

    for rh_gcs_file in $RH_GCS_FILES; do
        base_name=$(basename "$rh_gcs_file" .gcs)
        mris_ca_label -l "$SUBJECTS_DIR/sub-$subject/label/rh.cortex.label" \
            "$subject" rh "$SUBJECTS_DIR/sub-$subject/surf/rh.sphere.reg" \
            "$rh_gcs_file" \
            "$SUBJECTS_DIR/sub-$subject/label/${base_name}_order.annot"
    done
    
'''

    ])
"
# Capture the exit code of the Python script
exitcode=$?

# Log results to a table
for subject in ${SUBJECTS}; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    freesurfer failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done
