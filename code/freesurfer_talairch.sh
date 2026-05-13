#!/bin/bash
#SBATCH --job-name=freesurfer_notal
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=20:00:00

BASEDIR=${SLURM_SUBMIT_DIR}


export BIDS_DIR=${BASEDIR}/data/local/bids
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export APPTAINERENV_FS_LICENSE=/home/freesurfer/.freesurfer.txt

mkdir -vp ${OUTPUT_DIR} logs

############################################
# Get subject from participants.tsv
############################################

SUB=$(
  sed -n -E 's/^(sub-[^[:space:]]+).*/\1/p' \
  ${BIDS_DIR}/participants.tsv \
  | sed -n "$((SLURM_ARRAY_TASK_ID + 1))p"
)

echo "Running subject: ${SUB}"

############################################
# Get sessions from BIDS
############################################

SESSIONS=$(find ${BIDS_DIR}/${SUB} -maxdepth 1 -type d -name "ses-*" -printf "%f\n" | sort)

if [[ -z "${SESSIONS}" ]]; then
  echo "No sessions found for ${SUB}"
  exit 1
fi

echo "Found sessions:"
echo "${SESSIONS}"

############################################
# Step 1: Cross-sectional FreeSurfer
############################################

for ses in ${SESSIONS}; do
  sub_ses=${SUB}_${ses}
  T1=${BIDS_DIR}/${SUB}/${ses}/anat/${SUB}_${ses}_T1w.nii.gz

  if [[ ! -f "${T1}" ]]; then
    echo "Missing T1w: ${T1}, skipping ${sub_ses}"
    continue
  fi

  singularity exec --cleanenv \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    recon-all \
    -sd /derived \
    -subjid ${sub_ses} \
    -3T \
    -i /bids/${SUB}/${ses}/anat/${SUB}_${ses}_T1w.nii.gz \
    -all \
    -notal-check \
    -openmp ${SLURM_CPUS_PER_TASK}
done

############################################
# Step 2: Base template
############################################

TP_ARGS=""

for ses in ${SESSIONS}; do
  if [[ -d "${OUTPUT_DIR}/${SUB}_${ses}" ]]; then
    TP_ARGS="${TP_ARGS} -tp ${SUB}_${ses}"
  fi
done

echo "Timepoints for base:"
echo "${TP_ARGS}"

if [[ -z "${TP_ARGS}" ]]; then
  echo "No completed cross-sectional folders found for ${SUB}. Cannot run base."
  exit 1
fi

singularity exec --cleanenv \
  -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
  -B ${BIDS_DIR}:/bids \
  -B ${OUTPUT_DIR}:/derived \
  -B ${ORIG_FS_LICENSE}:/li \
  ${SING_CONTAINER} \
  recon-all \
  -sd /derived \
  -base ${SUB} \
  ${TP_ARGS} \
  -all \
  -notal-check \
  -openmp ${SLURM_CPUS_PER_TASK}

############################################
# Step 3: Longitudinal FreeSurfer
############################################

for ses in ${SESSIONS}; do
  sub_ses=${SUB}_${ses}

  if [[ ! -d "${OUTPUT_DIR}/${sub_ses}" ]]; then
    echo "Missing cross-sectional folder ${OUTPUT_DIR}/${sub_ses}, skipping long run"
    continue
  fi

  singularity exec --cleanenv \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    recon-all \
    -sd /derived \
    -long ${sub_ses} ${SUB} \
    -all \
    -notal-check \
    -openmp ${SLURM_CPUS_PER_TASK}
done

############################################
# Nipoppy tracker
############################################

export APPTAINERENV_ROOT_DIR=${BASEDIR}

singularity exec \
  --bind ${SCRATCH}:${SCRATCH} \
  --env SUBJECTS="${SUB}" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "${ROOT_DIR}/Neurobagel"

    mkdir -p derivatives/freesurferlong/7.4.1/output/

    ln -s "${ROOT_DIR}/data/local/derivatives/freesurfer/7.4.1/"* \
      derivatives/freesurferlong/7.4.1/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline freesurferlong \
        --pipeline-version 7.4.1 \
        --participant-id $subject
    done
  '

unset APPTAINERENV_ROOT_DIR
