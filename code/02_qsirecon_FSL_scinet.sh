#!/bin/bash
#SBATCH --job-name=qsirecon_fsl
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=01:00:00

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

export QSIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/qsiprep-0.22.0.sif

export OUTPUT_DIR=${BASEDIR}/data/local
export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep # use if version of fmriprep <=20.1

export WORK_DIR=${SLURM_TMPDIR}/SCanD/qsiprep
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


export fs_license=${BASEDIR}/templates/.freesurfer.txt

singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/qsiprep --home /home/qsiprep \
    -B ${BIDS_DIR}:/bids \
    -B ${QSIPREP_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    -B ${OUTPUT_DIR}:/out \
    -B ${fs_license}:/li \
    ${SING_CONTAINER} \
    /bids /out participant \
    --skip-bids-validation \
    --participant_label ${SUBJECTS} \
    -w /work \
    --skip-bids-validation \
    --omp-nthreads 8 \
    --nthreads 40 \
    --recon_only \
    --recon-spec reorient_fslstd \
    --recon-input /derived \
    --output-resolution 2.0 \
    --fs-license-file /li \
    --notrack


## nipoppy trackers

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind $BASEDIR:$BASEDIR \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"

    mkdir -p derivatives/qsireconfsl/0.22.0/output/
    ls -al derivatives/qsireconfsl/0.22.0/output/

    ln -s "$BASEDIR/data/local/qsirecon-FSL/" derivatives/qsireconfsl/0.22.0/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline qsireconfsl \
        --pipeline-version 0.22.0 \
        --participant-id sub-$subject
    done
  '
