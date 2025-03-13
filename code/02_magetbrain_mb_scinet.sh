#!/bin/bash
#SBATCH --job-name=magetbrain_mb
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=23:00:00

PROJECT_DIR=${SLURM_SUBMIT_DIR}

DATA_DIR=$PROJECT_DIR/data/local/MAGeTbrain/magetbrain_data
SING_CONTAINER=$PROJECT_DIR/containers/magetbrain.sif
LOGS_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOGS_DIR"

cd $PROJECT_DIR/..

singularity run \
   -B ${DATA_DIR}:/data \
   ${SING_CONTAINER} \
    mb --input_dir /data/input \
       --output_dir /data/output \
       --reg_dir /data/output/registration \
       --save \
       run \
       --stage-templatelib-walltime 24:00:00 \
       --stage-templatelib-procs 2 \
       --stage-voting-procs 1 \
       --stage-voting-walltime 24:00:00


exitcode=$?

if [ $exitcode -eq 0 ]; then
   echo "${SLURM_JOB_ID}    0" 
       >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_JOB_ID}.tsv
else
   echo "${SLURM_JOB_ID}    magetbrain failed" \
       >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_JOB_ID}.tsv
fi
