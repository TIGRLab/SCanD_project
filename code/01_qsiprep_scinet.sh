#!/bin/bash
#SBATCH --job-name=qsiprep
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --time=06:00:00
#SBATCH --mem-per-cpu=4000

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

module load apptainer/1.3.5
export BIDS_DIR=${BASEDIR}/data/local/bids

export QSIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/qsiprep-0.22.0.sif

export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0 # use if version of fmriprep <=20.1

# adding random string (project_id) to BBUFFER folder to prevent conflicts between projects
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


# Extract voxel sizes using fslinfo
first_session=$(find "${BIDS_DIR}/sub-${SUBJECTS}" -maxdepth 2 -type d -path "*/ses-*/dwi" | sort -V | head -n 1 | xargs dirname)

if [ -n "$(find "${BIDS_DIR}/sub-${SUBJECTS}" -maxdepth 1 -type d -name 'ses-*' -print -quit)" ]; then
voxel_info=$(singularity exec -B ${BASEDIR}/data/local/bids:/bids -B ${first_session}:/first_session containers/qsiprep-0.22.0.sif fslinfo /first_session/dwi/*.nii.gz)
else
voxel_info=$(singularity exec -B ${BASEDIR}/data/local/bids:/bids containers/qsiprep-0.22.0.sif fslinfo /bids/sub-${SUBJECTS}/dwi/*.nii.gz)
fi

# Extract voxel dimensions
voxdim1=$(echo "$voxel_info" | grep -oP 'pixdim1\s+\K\S+')
voxdim2=$(echo "$voxel_info" | grep -oP 'pixdim2\s+\K\S+')
voxdim3=$(echo "$voxel_info" | grep -oP 'pixdim3\s+\K\S+')

# Make all numbers positive and round to one decimal place
voxdim1=$(printf "%.1f" $voxdim1)
voxdim2=$(printf "%.1f" $voxdim2)
voxdim3=$(printf "%.1f" $voxdim3)

# Calculate the sum of voxel dimensions
sum=$(bc <<< "$voxdim1 + $voxdim2 + $voxdim3")
# Calculate the average
average=$(bc -l <<< "$sum / 3")
# Round the average to one decimal place
RESOLUTION=$(printf "%.1f" $average)


# --------------------------------------------
# Detect dwitopup fieldmaps
# --------------------------------------------
HAS_DWITOPUP=0

if find "${BIDS_DIR}/sub-${SUBJECTS}" \
    \( -path "*/ses-*/fmap/*dwitopup*.nii.gz" -o -path "*/fmap/*dwitopup*.nii.gz" \) \
    -print -quit | grep -q .; then
    HAS_DWITOPUP=1
fi

SDC_ARGS="--use-syn-sdc"

if [ "$HAS_DWITOPUP" -eq 0 ]; then
    echo "No dwitopup found for sub-${SUBJECTS} → using --force-syn"
    SDC_ARGS="${SDC_ARGS} --force-syn"
else
    echo "dwitopup found for sub-${SUBJECTS} → NOT forcing SyN"
fi

echo "SDC flags: ${SDC_ARGS}"


export SINGULARITYENV_FS_LICENSE=/home/qsiprep/.freesurfer.txt

singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/qsiprep --home /home/qsiprep \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    ${SING_CONTAINER} \
    /bids /derived participant \
    --participant_label ${SUBJECTS} \
    -w /work \
    --skip-bids-validation \
    --omp-nthreads 8 \
    --nthreads 40 \
    --mem-mb 15000 \
    --denoise-method dwidenoise \
    --unringing-method mrdegibbs \
    --separate_all_dwis \
    --hmc_model eddy \
    --output-resolution ${RESOLUTION}\
   ${SDC_ARGS}


## nipoppy trackers

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind ${BASEDIR}:${BASEDIR} \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"

    mkdir -p derivatives/qsiprep/0.22.0/output/
    ls -al derivatives/qsiprep/0.22.0/output/

    ln -s "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/qsiprep/"* derivatives/qsiprep/0.22.0/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline qsiprep \
        --pipeline-version 0.22.0 \
        --participant-id sub-$subject

      python "$BASEDIR/code/qsiprep_method_tsv.py" \
        --qsiprep-root "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/qsiprep" \
        --output-tsv "$BASEDIR/Neurobagel/derivatives/processing_status_qsiprep.tsv" \
        --participant-ids "sub-$subject"
    done
  '
