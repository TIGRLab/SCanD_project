#!/bin/bash

#SBATCH --job-name=noddi_reg
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=02:00:00


SUB_SIZE=1
export THREADS_PER_COMMAND=2
BASEDIR=${SLURM_SUBMIT_DIR}

# =========================
# PATHS
# =========================
export BIDS_DIR=${BASEDIR}/data/local/bids
export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer
export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep
export NODDI_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI
export CIFTIFY_DIR=${BASEDIR}/data/local/derivatives/ciftify/ciftify_noddi_reg
export CIFTIFY_PARC=${CIFTIFY_DIR}/ciftify_parcellations
export TEMPLATES_DIR=${BASEDIR}/templates/parcellations
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SING_CONTAINER=${BASEDIR}/containers/noddi_postproc-v.1.0.simg

mkdir -p "${CIFTIFY_DIR}" "${CIFTIFY_PARC}"

# =========================
# SUBJECT SELECTION
# =========================
bigger_bit=$(echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc)
N_SUBJECTS=$(( $(wc -l < ${BIDS_DIR}/participants.tsv) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [[ "${SLURM_ARRAY_TASK_ID}" -eq "${array_job_length}" ]]; then
  SUBJECTS=$(sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${N_SUBJECTS} | tail -n ${Tail})
else
  SUBJECTS=$(sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE})
fi


for subj in SUBJECTS_DIR/sub-*; do
    surfdir="$subj/surf"

    if [ -f "$surfdir/lh.pial.T1" ]; then
       	mv "$surfdir/lh.pial.T1" "$surfdir/lh.pial"
    fi

    if [ -f "$surfdir/rh.pial.T1" ]; then
       	mv "$surfdir/rh.pial.T1" "$surfdir/rh.pial"
    fi
done

# =========================
# MAIN LOOP
# =========================
for SUBJECT in ${SUBJECTS}; do
  subj_id="sub-${SUBJECT}"

  # ---- Sessions ----
  SESSIONS=$(find "${BIDS_DIR}/${subj_id}" -maxdepth 1 -type d -name "ses-*" -printf "%f\n" | sed 's/ses-//')
  [[ -z "${SESSIONS}" ]] && SESSIONS="01"

  for session in ${SESSIONS}; do

    # =========================
    # CROSS vs LONG DECISION
    # =========================
    LONG_FS_DIR="${SUBJECTS_DIR}/${subj_id}_ses-${session}.long.${subj_id}"

    if [[ -d "${LONG_FS_DIR}" ]]; then
      echo "→ Using LONGITUDINAL anatomy for ${subj_id} ses-${session}"
      ANAT_ID="${subj_id}_ses-${session}.long.${subj_id}"
    else
      echo "→ Using CROSS-SECTIONAL anatomy for ${subj_id}"
      ANAT_ID="${subj_id}"
    fi

    parc_dir="${CIFTIFY_PARC}/${ANAT_ID}/anat"
    mkdir -p "${parc_dir}"

    # =========================
    # STEP 1: CIFTIFY
    # =========================
    singularity exec --cleanenv \
      -B "${SUBJECTS_DIR}:/freesurfer" \
      -B "${CIFTIFY_DIR}:/out" \
      -B "${ORIG_FS_LICENSE}:/li" \
      "${SING_CONTAINER}" \
      ciftify_recon_all \
        --fs-subjects-dir /freesurfer \
        --ciftify-work-dir /out/ciftify \
        --fs-license /li \
        --resample-to-T1w32k \
        --surf-reg FS \
        "${ANAT_ID}"

    cp "${CIFTIFY_DIR}/ciftify/${ANAT_ID}/T1w/aparc+aseg.nii.gz" \
       "${parc_dir}/${subj_id}_ses-${session}_space-T1w_desc-aparcaseg_dseg.nii.gz"

    cp "${CIFTIFY_DIR}/ciftify/${ANAT_ID}/T1w/wmparc.nii.gz" \
       "${parc_dir}/${subj_id}_ses-${session}_space-T1w_desc-wmparc_dseg.nii.gz"

    # =========================
    # STEP 2: DLABEL → VOL
    # =========================
    for parc_file in ${TEMPLATES_DIR}/tpl-fsLR_res-91k_atlas-*_dseg.dlabel.nii; do
      parc_name=$(basename "${parc_file}" | sed -E 's/.*atlas-(.*)_dseg\.dlabel\.nii/\1/')

      OUT_NII="${CIFTIFY_PARC}/${subj_id}_ses-${session}_space-T1w_desc-${parc_name}_dseg.nii.gz"

      if [[ -f "${OUT_NII}" ]]; then
        echo "✓ Stage 2: ${parc_name} already exists — skipping"
        continue
      fi

      echo "→ Stage 2: converting ${parc_name}"

      singularity exec --cleanenv \
        -B "${TEMPLATES_DIR}:/templates" \
        -B "${CIFTIFY_DIR}:/out" \
        -B "${CIFTIFY_PARC}:/parc" \
        -B "${BASEDIR}/code:/code" \
        "${SING_CONTAINER}" \
        /opt/conda/envs/fmriprep/bin/python /code/ciftify_dlabel_to_vol.py \
          --cortex-only \
          --input-dlabel "/templates/$(basename ${parc_file})" \
          --left-mid-surface "/out/ciftify/${ANAT_ID}/T1w/fsaverage_LR32k/${ANAT_ID}.L.midthickness.32k_fs_LR.surf.gii" \
          --volume-template "/out/ciftify/${ANAT_ID}/T1w/T1w.nii.gz" \
          --output-nifti "/parc/${ANAT_ID}/anat/${subj_id}_ses-${session}_space-T1w_desc-${parc_name}_dseg.nii.gz"
    done

    # =========================
    # STEP 3: ACPC TRANSFORM
    # =========================
    ref_file=$(find "${QSIPREP_DIR}/${subj_id}/ses-${session}/dwi" -name "*_space-T1w_dwiref.nii.gz" | head -n 1)
    xfm_file="${QSIPREP_DIR}/${subj_id}/anat/${subj_id}_from-T1wNative_to-T1wACPC_mode-image_xfm.mat"

    for parc in aparcaseg wmparc Glasser Gordon 4S1056Parcels 4S156Parcels 4S256Parcels 4S356Parcels 4S456Parcels 4S556Parcels 4S656Parcels 4S756Parcels 4S856Parcels 4S956Parcels; do
      singularity exec --cleanenv \
        -B "${QSIPREP_DIR}:/qsiprep" \
        -B "${CIFTIFY_PARC}:/parc" \
        "${SING_CONTAINER}" \
        antsApplyTransforms -d 3 \
          -i "/parc/${ANAT_ID}/anat/${subj_id}_ses-${session}_space-T1w_desc-${parc}_dseg.nii.gz" \
          -r "/qsiprep/${ref_file#${QSIPREP_DIR}/}" \
          -t "/qsiprep/${xfm_file#${QSIPREP_DIR}/}" \
          --interpolation GenericLabel \
          -o "/parc/${ANAT_ID}/anat/${subj_id}_ses-${session}_space-ACPC_desc-${parc}_dseg.nii.gz"
    done

    # =========================
    # STEP 4: METRIC EXTRACTION
    # =========================
    cp ${TEMPLATES_DIR}/*dseg.tsv ${CIFTIFY_PARC}/

    singularity exec --cleanenv \
      -B "${BASEDIR}/code:/code" \
      -B "${QSIPREP_DIR}:/qsiprep" \
      -B "${NODDI_DIR}:/noddi" \
      -B "${CIFTIFY_PARC}:/parc" \
      "${SING_CONTAINER}" \
      /opt/conda/envs/fmriprep/bin/python /code/extract_subject_noddi_metrics_v2.py \
        --subject "${SUBJECT}" \
        --session "${session}" \
        --parc-dir "/parc" \
        --anat-id "${ANAT_ID}" \
        --qsiprep-dir "/qsiprep" \
        --amico-noddi-dir "/noddi"

  done
done





## nipoppy trackers

export APPTAINERENV_ROOT_DIR=${BASEDIR}

singularity exec \
  --bind ${SCRATCH}:${SCRATCH} \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    BASEDIR="$SCRATCH/SCanD_project"
    cd "${ROOT_DIR}/Neurobagel"

    mkdir -p derivatives/noddireg/0.22.0/output/
    ls -al derivatives/noddireg/0.22.0/output/

    ln -s "${ROOT_DIR}/data/local/derivatives/ciftify/ciftify_noddi_reg/"* derivatives/noddireg/0.22.0/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline noddireg \
        --pipeline-version 0.22.0 \
        --participant-id sub-$subject
    done
  '
unset APPTAINERENV_ROOT_DIR
