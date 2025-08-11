#!/bin/bash
#SBATCH --job-name=magetbrain_register
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=23:59:00

BASEDIR=${SLURM_SUBMIT_DIR}

DATA_DIR=$BASEDIR/data/local/derivatives/MAGeTbrain/magetbrain_data
SING_CONTAINER=$BASEDIR/containers/magetbrain.sif
LOGS_DIR="$BASEDIR/logs"

mkdir -p "$LOGS_DIR"

cd $BASEDIR/..

singularity run \
   -B ${DATA_DIR}:/data \
   ${SING_CONTAINER} \
    mb --input_dir /data/input \
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
cd $BASEDIR/

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --env SUBJECTS_BATCH="$SUBJECTS_BATCH" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail
    
    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/magetbrainregister/0.1.0/output/
    ls -al derivatives/magetbrainregister/0.1.0/output/

    ln -s "$BASEDIR/data/local/derivatives/MAGeTbrain/magetbrain_data/"* derivatives/magetbrainregister/0.1.0/output/ || true

    nipoppy track  --pipeline magetbrainregister  --pipeline-version 0.1.0
  '
