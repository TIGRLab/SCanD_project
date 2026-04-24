#!/bin/bash
#SBATCH --job-name=glm
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=6
#SBATCH --time=08:00:00
#SBATCH --mem-per-cpu=8000
#SBATCH --account=rrg-arisvoin

SUB_SIZE=1 ## number of subjects to run is 1 because there are multiple tasks/run that will run in parallel
export THREADS_PER_COMMAND=2
BASEDIR=${SLURM_SUBMIT_DIR}

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

module load apptainer/1.3.5

# Set-up inputs
export BIDS_DIR=${BASEDIR}/data/local/bids
export FMRIPREP_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4
export OUT_DIR=${BASEDIR}/data/local/derivatives/glm/0.0.1
if [ -z "$1" ]; then
    echo "ERROR: No model file specified. Pass the absolute path to your task-specific model JSON as the first argument."
    echo "  sbatch --array=0-\${array_job_length} code/02_glm_surface_scinet.sh \$PWD/code/glm/examples/models/your-model.json"
    exit 1
fi
export MODEL=$1

mkdir -p $OUT_DIR

# Parsing subject
# start=$(($SLURM_ARRAY_TASK_ID * SUB_SIZE + 1))
# end=$((start + SUB_SIZE - 1))

# SUBJECTS=$(sed -n -E "s/sub-(\S*).*/\1/p" ${BIDS_DIR}/participants.tsv \
#     | sed -n "${start},${end}p")
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`
N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

echo singularity run --cleanenv \
    -B ${BIDS_DIR}:/bids \
    -B ${FMRIPREP_DIR}:/fmriprep \
    -B ${OUT_DIR}:/outdir \
    -B ${MODEL}:/model \
    ${SCRATCH}/RTMSWM/SCanD_project/containers/glm-0.0.1.sif \
    /bids /fmriprep \
    --output_dir /outdir \
    --participant-label ${SUBJECTS} \
    --model /model \
    --drop-duration 4

singularity run --cleanenv \
    -B ${BIDS_DIR}:/bids \
    -B ${FMRIPREP_DIR}:/fmriprep \
    -B ${OUT_DIR}:/outdir \
    -B ${MODEL}:/model \
    ${SCRATCH}/RTMSWM/SCanD_project/containers/glm-0.0.1.sif \
    /bids /fmriprep \
    --output_dir /outdir \
    --participant-label ${SUBJECTS} \
    --model /model \
    --drop-duration 4

## nipoppy trackers 
export APPTAINERENV_ROOT_DIR=${BASEDIR}

singularity exec \
  --bind ${SCRATCH}:${SCRATCH} \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
   set -euo pipefail
   cd "${ROOT_DIR}/Neurobagel"
   mkdir -p derivatives/glm/0.0.1/output/

   shopt -s nullglob
   ln -s "${ROOT_DIR}/data/local/derivatives/glm/0.0.1/"* derivatives/glm/0.0.1/output/ 2>/dev/null || true
   shopt -u nullglob

   for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline glm \
        --pipeline-version 0.0.1 \
        --participant-id sub-$subject
    done
 '
unset APPTAINERENV_ROOT_DIR
