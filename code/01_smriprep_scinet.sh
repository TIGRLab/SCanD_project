#!/bin/bash
#SBATCH --job-name=smriprep
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=10:00:00


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

export SMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/fmriprep-25.2.4.simg


export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/smriprep/25.2.4

export WORK_DIR=${SLURM_TMPDIR}/SCanD/smriprep
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

export FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

singularity exec --cleanenv \
    -B ${BASEDIR}/templates:/home/fmriprep --home /home/fmriprep \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    -B ${FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    smriprep /bids /derived participant --participant_label ${SUBJECTS} -w /work  --omp-nthreads 8  --nthreads 40  --notrack --fs-license-file /li


## nipoppy trackers

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"

    mkdir -p derivatives/smriprep/25.2.4/output/
    ls -al derivatives/smriprep/25.2.4/output/
    ln -s "$BASEDIR/data/local/derivatives/smriprep/25.2.4/smriprep/"* derivatives/smriprep/25.2.4/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline smriprep \
        --pipeline-version 25.2.4 \
        --participant-id sub-$subject
    done
  '
