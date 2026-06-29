#!/bin/bash
#SBATCH --job-name=xcp
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=03:00:00


SUB_SIZE=1
export THREADS_PER_COMMAND=2


BASEDIR=${SLURM_SUBMIT_DIR}

function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

trap "cleanup_ramdisk" TERM

export BIDS_DIR=${BASEDIR}/data/local/bids

export SING_CONTAINER=${BASEDIR}/containers/xcp_d-0.7.3.simg


export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/xcp_d/0.7.3
export FMRI_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4

export WORK_DIR=${SLURM_TMPDIR}/SCanD/xcp
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR}

bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

singularity run --cleanenv \
-B ${BASEDIR}/templates:/home/fmriprep --home /home/fmriprep \
-B ${OUTPUT_DIR}:/out \
-B ${FMRI_DIR}:/fmriprep \
-B ${WORK_DIR}:/work \
-B ${ORIG_FS_LICENSE}:/li \
${SING_CONTAINER} \
    /fmriprep \
    /out \
    participant \
    --participant_label ${SUBJECTS} \
    -w /work \
    --cifti \
    --fs-license-file /li \
    --smoothing 0 \
    --fd-thresh 0 \
    --dummy-scans 3 \
    --notrack


## nipoppy trackers

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"

    mkdir -p derivatives/xcpd/0.7.3/output/
    ls -al derivatives/xcpd/0.7.3/output/

    ln -s "$BASEDIR/data/local/derivatives/xcp_d/0.7.3/"* derivatives/xcpd/0.7.3/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline xcpd \
        --pipeline-version 0.7.3  \
        --participant-id sub-$subject
    done
  '
