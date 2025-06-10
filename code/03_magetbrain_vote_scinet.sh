#!/bin/bash
#SBATCH --job-name=magetbrain_vote
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=10:00:00

PROJECT_DIR=${SLURM_SUBMIT_DIR}

DATA_DIR=$PROJECT_DIR/data/local/derivatives/MAGeTbrain/magetbrain_data
SING_CONTAINER=$PROJECT_DIR/containers/magetbrain.sif
LOGS_DIR="$PROJECT_DIR/logs"

mkdir -p "$LOGS_DIR"

SUB_SIZE=1

bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`
SUBJECTS_LIST=($(ls $PROJECT_DIR/data/local/derivatives/MAGeTbrain/magetbrain_data/input/subjects/brains/*.mnc | xargs -n 1 basename | sed 's/\.mnc$//'))

N_SUBJECTS=${#SUBJECTS_LIST[@]}
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS - (array_job_length * SUB_SIZE)))

SUBJECTS=("${SUBJECTS_LIST[@]:bigger_bit-SUB_SIZE:SUB_SIZE}")


cd $PROJECT_DIR/..

singularity run \
   -B ${DATA_DIR}:/data \
   ${SING_CONTAINER} \
    mb --input_dir /data/input \
       --output_dir /data/output \
       --reg_dir /data/output/registration \
       --save \
       run \
       vote \
       --subject ${SUBJECTS} \
       --stage-templatelib-walltime 24:00:00 \
       --stage-templatelib-procs 2 \
       --stage-voting-procs 1 \
       --stage-voting-walltime 24:00:00


## nipoppy trackers 

singularity exec \
  --bind ${SCRATCH}:${SCRATCH} \
  --env SUBJECTS="$SUBJECTS" \
  containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    BASEDIR="$SCRATCH/SCanD_project"
    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/magetbrainvote/0.1.0/output/
    ls -al derivatives/magetbrainvote/0.1.0/output/

    ln -s "$BASEDIR/data/local/derivatives/MAGeTbrain/magetbrain_data/output/"* derivatives/magetbrainvote/0.1.0/output/ || true

    SUBJECTS=$(echo "$SUBJECTS" | cut -d'_' -f1)

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline magetbrainvote \
        --pipeline-version 0.1.0 \
        --participant-id $subject
    done
  '
