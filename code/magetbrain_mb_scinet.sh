#!/bin/bash
#SBATCH --job-name=maget_brain
#SBATCH --output=log/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --time=16:00:00
#SBATCH --mem-per-cpu=60000

module load apptainer/1.3.5

LOG_DIR=$SCRATCH/SCanD_project/data/local/MAGeTbrain/log
DATA_DIR=$SCRATCH/data/local/MAGeTbrain/magetbrain_data
SING_CONTAINER=$SCRATCH/SCanD_project/containers/magetbrain.sif

mkdir -p $LOG_DIR

cd ~

singularity run \
   -B ${DATA_DIR}:/data \
   ${SING_CONTAINER} \
    mb --input_dir /data/input \
       --output_dir /data/output \
       --reg_dir /data/output/registration \
       --save \
       run

exitcode=$?

if [ $exitcode -eq 0 ]; then
   echo "${SLURM_ARRAY_TASK_ID}    0" 
       >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
else
   echo "${SLURM_ARRAY_TASK_ID}    magetbrain failed" \
       >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
fi
