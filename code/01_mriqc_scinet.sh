#!/bin/bash
#SBATCH --job-name=mriqc
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --time=08:00:00
#SBATCH --mem-per-cpu=16000

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
module load apptainer/1.3.5

trap "cleanup_ramdisk" TERM

export BIDS_DIR=${BASEDIR}/data/local/bids

export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/mriqc-24.0.0.simg


export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/mriqc/24.0.0 # use if version of fmriprep <=20.1

export WORK_DIR=${SLURM_TMPDIR}/SCanD/mriqc
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
    --mem_gb 12 \
    --no-datalad-get \
    --no-sub


## nipoppy trackers

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind ${BASEDIR}:${BASEDIR} \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"
    mkdir -p derivatives/mriqc/24.0.0/output/
    ls -al derivatives/mriqc/24.0.0/output/
    ln -s "$BASEDIR/data/local/derivatives/mriqc/24.0.0/"* derivatives/mriqc/24.0.0/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline mriqc \
        --pipeline-version 24.0.0 \
        --participant-id sub-$subject
    done
  '
