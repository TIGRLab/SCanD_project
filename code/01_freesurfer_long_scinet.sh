#!/bin/bash
#SBATCH --job-name=freesurfer
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=20:00:00
#SBATCH --mem-per-cpu=4000

SUB_SIZE=1


BASEDIR=${SLURM_SUBMIT_DIR}

function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

trap "cleanup_ramdisk" TERM

module load apptainer/1.3.5
export BIDS_DIR=${BASEDIR}/data/local/bids

export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg


export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1

export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${LOGS_DIR}

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

singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    /bids /derived participant \
    --participant_label ${SUBJECTS} \
    --skip_bids_validator \
    --license_file /li \
    --n_cpus 80


## nipoppy trackers

export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
SUBJECT_LONG_DIRS=$(find "$SUBJECTS_DIR" -maxdepth 1 -type d -name "*.long.*" | head -n 1)

if [[ -z "$SUBJECT_LONG_DIRS" ]]; then
    # No longitudinal dirs → use notlong tracker_config
    rm -rf Neurobagel/pipelines/processing/freesurferlong-7.4.1/tracker_config.json
    cp -r /scratch/arisvoin/shared/freesurfer_notlong/freesurfer/tracker_config.json \
          Neurobagel/pipelines/processing/freesurferlong-7.4.1/
else
    # Longitudinal dirs found → use long tracker_config
    rm -rf Neurobagel/pipelines/processing/freesurferlong-7.4.1/tracker_config.json
    cp -r /scratch/arisvoin/shared/nipoppy/freesurferlong-7.4.1/tracker_config.json \
          Neurobagel/pipelines/processing/freesurferlong-7.4.1/
fi


singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind ${BASEDIR}:${BASEDIR} \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    mkdir -p derivatives/freesurferlong/7.4.1/output/
    ls -al derivatives/freesurferlong/7.4.1/output/
    ln -s "$BASEDIR/data/local/derivatives/freesurfer/7.4.1/"* derivatives/freesurferlong/7.4.1/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline freesurferlong \
        --pipeline-version 7.4.1 \
        --participant-id sub-$subject
    done
  '
