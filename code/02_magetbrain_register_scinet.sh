#!/bin/bash
#SBATCH --job-name=magetbrain_register
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --time=23:59:00
#SBATCH --mem-per-cpu=8000

module load apptainer/1.3.5

PROJECT_DIR=${SLURM_SUBMIT_DIR}

DATA_DIR=$PROJECT_DIR/data/local/derivatives/MAGeTbrain/magetbrain_data
SING_CONTAINER=$PROJECT_DIR/containers/magetbrain.sif
LOGS_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOGS_DIR"

cd $PROJECT_DIR/..

singularity run \
   -B ${DATA_DIR}:/data \
   ${SING_CONTAINER} \
    mb \
       --input_dir /data/input \
       --output_dir /data/output \
       --reg_dir /data/output/registration \
       --save \
       run \
       register \
       --stage-templatelib-walltime 24:00:00 \
       --stage-templatelib-procs 2 \
       --stage-voting-procs 1 \
       --stage-voting-walltime 24:00:00


## nipoppy trackers 
export APPTAINERENV_ROOT_DIR=${PROJECT_DIR}

singularity exec \
  --bind ${SCRATCH}:${SCRATCH} \
  --env SUBJECTS_BATCH="$SUBJECTS_BATCH" \
  ${PROJECT_DIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    BASEDIR="$SCRATCH/SCanD_project"
    cd "${ROOT_DIR}/Neurobagel"
    
    mkdir -p derivatives/magetbrainregister/0.1.0/output/
    ls -al derivatives/magetbrainregister/0.1.0/output/

    ln -s "${ROOT_DIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/"* derivatives/magetbrainregister/0.1.0/output/ || true

    nipoppy track  --pipeline magetbrainregister  --pipeline-version 0.1.0
  '
unset APPTAINERENV_ROOT_DIR
