#!/bin/bash
#SBATCH --job-name=noddi_reg
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=04:00:00
#SBATCH --mem-per-cpu=4000

set -euo pipefail

SUB_SIZE=1
export THREADS_PER_COMMAND=2
BASEDIR=${SLURM_SUBMIT_DIR}

module load apptainer/1.3.5
module load StdEnv/2023
module load connectomeworkbench/2.0.1
module load fsl

# =========================
# PATHS
# =========================
export BIDS_DIR=${BASEDIR}/data/local/bids
export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4/sourcedata/freesurfer
export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep
export NODDI_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI
export CIFTIFY_DIR=${BASEDIR}/data/local/derivatives/ciftify/ciftify_noddi_reg
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/noddi_reg
export TEMPLATES_DIR=${BASEDIR}/templates/parcellations
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SING_CONTAINER=${BASEDIR}/containers/noddi_postproc-v.1.0.simg
export QC_CONTAINER=${BASEDIR}/containers/fmriprep-25.2.4.simg

mkdir -p "${CIFTIFY_DIR}" "${OUTPUT_DIR}" logs

export FREESURFER_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4/sourcedata/freesurfer

# =========================
# SUBJECT SELECTION
# =========================
bigger_bit=$(echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc)
N_SUBJECTS=$(( $(wc -l < "${BIDS_DIR}/participants.tsv") - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS - (array_job_length * SUB_SIZE)))

if [[ "${SLURM_ARRAY_TASK_ID}" -eq "${array_job_length}" ]]; then
  SUBJECTS=$(sed -n -E "s/sub-(\S*)\>.*/\1/gp" "${BIDS_DIR}/participants.tsv" | head -n "${N_SUBJECTS}" | tail -n "${Tail}")
else
  SUBJECTS=$(sed -n -E "s/sub-(\S*)\>.*/\1/gp" "${BIDS_DIR}/participants.tsv" | head -n "${bigger_bit}" | tail -n "${SUB_SIZE}")
fi

fix_fs_surf_names() {
  local subj_id="sub-${1}"
  local surfdir="${SUBJECTS_DIR}/${subj_id}/surf"

  [[ -d "${surfdir}" ]] || return 0

  if [[ -f "${surfdir}/lh.pial.T1" && ! -e "${surfdir}/lh.pial" ]]; then
    mv "${surfdir}/lh.pial.T1" "${surfdir}/lh.pial"
  fi
  if [[ -f "${surfdir}/rh.pial.T1" && ! -e "${surfdir}/rh.pial" ]]; then
    mv "${surfdir}/rh.pial.T1" "${surfdir}/rh.pial"
  fi
}

for SUBJECT in ${SUBJECTS}; do
  for d in ${FREESURFER_DIR}/sub-${SUBJECT}_ses-*; do
    [[ -e "${d}" ]] || continue
    subj="${d%%_ses-*}"
    ln -sfn "$(basename "${d}")" "${subj}"
  done
  fix_fs_surf_names "${SUBJECT}"
done

############################
# STEP 1: CIFTIFY
############################
for SUBJECT in ${SUBJECTS}; do
  subj_id="sub-${SUBJECT}"
  CIFTIFY_SUBJ_DIR="${CIFTIFY_DIR}/ciftify/${subj_id}"

  if [[ -d "${CIFTIFY_SUBJ_DIR}" ]]; then
    echo "[STEP1] Removing existing ciftify output for ${subj_id}"
    rm -rf "${CIFTIFY_SUBJ_DIR}"
  fi

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
      "${subj_id}"

  mkdir -p "${OUTPUT_DIR}/${subj_id}/anat"

  cp "${CIFTIFY_DIR}/ciftify/${subj_id}/T1w/aparc+aseg.nii.gz" \
     "${OUTPUT_DIR}/${subj_id}/anat/${subj_id}_space-ciftifyT1_desc-aparcaseg_dseg.nii.gz"

  cp "${CIFTIFY_DIR}/ciftify/${subj_id}/T1w/wmparc.nii.gz" \
     "${OUTPUT_DIR}/${subj_id}/anat/${subj_id}_space-ciftifyT1_desc-wmparc_dseg.nii.gz"
done

###############################################################################
# STEPS 2 -> 4
###############################################################################
for SUBJECT in ${SUBJECTS}; do
  SUBJ="sub-${SUBJECT}"
  mkdir -p "${OUTPUT_DIR}/${SUBJ}/anat"

  # -------------------------
  # STEP 2: dlabel -> ciftifyT1 parcel volume(s)
  # -------------------------
  CIFTI_T1="${CIFTIFY_DIR}/ciftify/${SUBJ}/T1w/T1w.nii.gz"
  [[ -f "${CIFTI_T1}" ]] || CIFTI_T1="${CIFTIFY_DIR}/ciftify/${SUBJ}/T1w/T1w_acpc_dc.nii.gz"
  [[ -f "${CIFTI_T1}" ]] || { echo "[ERROR] Missing ciftify T1 volume for ${SUBJ}"; exit 1; }

  for parc_file in "${TEMPLATES_DIR}"/tpl-fsLR_res-91k_atlas-*_dseg.dlabel.nii; do
    parc_name=$(basename "${parc_file}" | sed -E 's/.*atlas-(.*)_dseg\.dlabel\.nii/\1/')
    OUT_CIFTI="${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ciftifyT1_desc-${parc_name}_dseg.nii.gz"

    if [[ ! -f "${OUT_CIFTI}" ]]; then
      singularity exec --cleanenv \
        -B "${TEMPLATES_DIR}:/templates" \
        -B "${CIFTIFY_DIR}:/out" \
        -B "${OUTPUT_DIR}:/parc" \
        -B "${BASEDIR}/code:/code" \
        "${SING_CONTAINER}" \
        /opt/conda/envs/fmriprep/bin/python /code/ciftify_dlabel_to_vol.py --cortex-only \
          --input-dlabel "/templates/$(basename "${parc_file}")" \
          --left-mid-surface "/out/ciftify/${SUBJ}/T1w/fsaverage_LR32k/${SUBJ}.L.midthickness.32k_fs_LR.surf.gii" \
          --volume-template "/out/ciftify/${SUBJ}/T1w/$(basename "${CIFTI_T1}")" \
          --output-nifti "/parc/${SUBJ}/anat/$(basename "${OUT_CIFTI}")"
    fi
  done

  # -------------------------
  # STEP 2.1: compute ciftifyT1 -> QSIPrep T1w affine
  # -------------------------
  QSI_T1="${QSIPREP_DIR}/${SUBJ}/anat/${SUBJ}_desc-preproc_T1w.nii.gz"
  [[ -f "${QSI_T1}" ]] || { echo "[ERROR] Missing QSIPrep T1w for ${SUBJ}"; exit 1; }

  XFM_DIR="${OUTPUT_DIR}/${SUBJ}/anat/xfm_ciftiT1_to_qsiT1"
  mkdir -p "${XFM_DIR}"

  AFF="${XFM_DIR}/c2q_0GenericAffine.mat"
  if [[ ! -f "${AFF}" ]]; then
    singularity exec --cleanenv \
      -B "${QSIPREP_DIR}:/qsiprep" \
      -B "${CIFTIFY_DIR}:/ciftify" \
      -B "${OUTPUT_DIR}:/parc" \
      "${SING_CONTAINER}" \
      antsRegistrationSyNQuick.sh -d 3 \
        -f "/qsiprep/${SUBJ}/anat/${SUBJ}_desc-preproc_T1w.nii.gz" \
        -m "/ciftify/ciftify/${SUBJ}/T1w/$(basename "${CIFTI_T1}")" \
        -t a \
        -o "/parc/${SUBJ}/anat/xfm_ciftiT1_to_qsiT1/c2q_"
  fi
  [[ -f "${AFF}" ]] || { echo "[ERROR] Missing c2q affine for ${SUBJ}: ${AFF}"; exit 1; }

  # -------------------------
  # STEP 2.2: apply c2q affine to parcels -> QSIPrep T1w parcels
  # -------------------------
  for in_cifti in "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ciftifyT1_desc-"*_dseg.nii.gz; do
    [[ -f "${in_cifti}" ]] || continue
    desc=$(basename "${in_cifti}" | sed -E 's/.*_desc-([^_]+)_dseg\.nii\.gz/\1/')
    OUT_T1="${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_desc-${desc}_dseg.nii.gz"

    if [[ ! -f "${OUT_T1}" ]]; then
      singularity exec --cleanenv \
        -B "${QSIPREP_DIR}:/qsiprep" \
        -B "${OUTPUT_DIR}:/parc" \
        "${SING_CONTAINER}" \
        antsApplyTransforms -d 3 \
          -i "/parc/${SUBJ}/anat/$(basename "${in_cifti}")" \
          -r "/qsiprep/${SUBJ}/anat/${SUBJ}_desc-preproc_T1w.nii.gz" \
          -t "/parc/${SUBJ}/anat/xfm_ciftiT1_to_qsiT1/$(basename "${AFF}")" \
          -n GenericLabel \
          -o "/parc/${SUBJ}/anat/$(basename "${OUT_T1}")"
    fi
  done

  # -------------------------
  # STEP 3: resample QSIPrep T1w parcels to dwiref grid USING FLIRT (-usesqform)
  # -------------------------
  SESSIONS=$(find "${BIDS_DIR}/${SUBJ}" -maxdepth 2 -type d -path "*/ses-*/dwi" \
    | sort -V | xargs -n1 dirname | xargs -n1 basename | sed 's/^ses-//')
  [[ -z "${SESSIONS}" ]] && SESSIONS="01"

  for session in ${SESSIONS}; do
    SES="ses-${session}"

    DWIRREF=$(find "${QSIPREP_DIR}/${SUBJ}/${SES}/dwi" -name "*_space-T1w_dwiref.nii.gz" | head -n 1)
    [[ -f "${DWIRREF}" ]] || { echo "[ERROR] Missing dwiref for ${SUBJ} ${SES}"; exit 1; }

    for parc_t1 in "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_desc-"*_dseg.nii.gz; do
      [[ -f "${parc_t1}" ]] || continue
      desc=$(basename "${parc_t1}" | sed -E 's/.*_desc-([^_]+)_dseg\.nii\.gz/\1/')

      OUT_DWI="${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_ref-dwiref_desc-${desc}_dseg.nii.gz"

      if [[ ! -f "${OUT_DWI}" ]]; then
        flirt -in "${parc_t1}" -ref "${DWIRREF}" \
          -applyxfm -usesqform \
          -interp nearestneighbour \
          -out "${OUT_DWI}"
      fi

      # STEP 3.1: ACPC symlink for Step 4 compatibility
      PARC_ACPC="${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ACPC_desc-${desc}_dseg.nii.gz"
      ln -sf "${OUT_DWI}" "${PARC_ACPC}"
    done
  done

  # -------------------------
  # STEP 4: Metric extraction (per session)
  # -------------------------
  cp "${TEMPLATES_DIR}"/*dseg.tsv "${OUTPUT_DIR}/" || true

  for session in ${SESSIONS}; do
    singularity exec --cleanenv \
      -B "${BASEDIR}/code:/code" \
      -B "${QSIPREP_DIR}:/qsiprep" \
      -B "${NODDI_DIR}:/noddi" \
      -B "${OUTPUT_DIR}:/parc" \
      "${SING_CONTAINER}" \
      /opt/conda/envs/fmriprep/bin/python /code/extract_subject_noddi_metrics.py \
        --subject "${SUBJECT}" \
        --session "${session}" \
        --parc-dir "/parc" \
        --qsiprep-dir "/qsiprep" \
        --amico-noddi-dir "/noddi"
  done
done

###############################################################################
# STEP 5: TSV -> PSCALAR + QC PNG (OD / ICVF / ISOVF)
###############################################################################
QC_CONTAINER=${BASEDIR}/containers/fmriprep-25.2.4.simg

CIFTI_TMP_DIR="${OUTPUT_DIR}/_cifti_templates"
mkdir -p "${CIFTI_TMP_DIR}"

DLABEL_4S1056="${TEMPLATES_DIR}/tpl-fsLR_res-91k_atlas-4S1056Parcels_dseg.dlabel.nii"

for SUBJECT in ${SUBJECTS}; do
  subj_id="sub-${SUBJECT}"

  SESSIONS=$(find "${BIDS_DIR}/${subj_id}" -maxdepth 2 -type d -path "*/ses-*/dwi" \
    | sort -V | xargs -n1 dirname | xargs -n1 basename | sed 's/^ses-//')
  [[ -z "${SESSIONS}" ]] && SESSIONS="01"

  SURF_DIR_SUBJ="${CIFTIFY_DIR}/ciftify/${subj_id}/MNINonLinear/fsaverage_LR32k"
  DENSE_TEMPLATE="${SURF_DIR_SUBJ}/${subj_id}.thickness.32k_fs_LR.dscalar.nii"
  [[ ! -f "${DENSE_TEMPLATE}" ]] && DENSE_TEMPLATE="${SURF_DIR_SUBJ}/${subj_id}.sulc.32k_fs_LR.dscalar.nii"

  if [[ ! -d "${SURF_DIR_SUBJ}" || ! -f "${DENSE_TEMPLATE}" ]]; then
    echo "[WARN] Missing ciftify outputs for ${subj_id}, skipping Step 5."
    continue
  fi

  TEMPLATE_PSCALAR="${CIFTI_TMP_DIR}/${subj_id}_template_4S1056.pscalar.nii"
  if [[ ! -f "${TEMPLATE_PSCALAR}" ]]; then
    wb_command -cifti-math "0" "${CIFTI_TMP_DIR}/${subj_id}_zero.dscalar.nii" -var x "${DENSE_TEMPLATE}"
    wb_command -cifti-parcellate \
      "${CIFTI_TMP_DIR}/${subj_id}_zero.dscalar.nii" \
      "${DLABEL_4S1056}" \
      COLUMN \
      "${TEMPLATE_PSCALAR}"
  fi

  for session in ${SESSIONS}; do
    ses_id="ses-${session}"

    TSV="${OUTPUT_DIR}/${subj_id}/${ses_id}/dwi/${subj_id}_${ses_id}_desc-4S1056Parcels_model-noddi_results.tsv"
    if [[ ! -f "${TSV}" ]]; then
      TSV=$(find "${OUTPUT_DIR}/${subj_id}" -type f -name "${subj_id}_${ses_id}*4S1056Parcels*results.tsv" | head -n 1 || true)
    fi
    if [[ -z "${TSV}" || ! -f "${TSV}" ]]; then
      echo "[WARN] TSV not found for ${subj_id} ${ses_id}, skipping."
      continue
    fi

    DWI_OUT_DIR="$(dirname "${TSV}")"

    for METRIC in od_mean icvf_mean isovf_mean; do
      VEC_TXT="${DWI_OUT_DIR}/${subj_id}_${ses_id}_${METRIC}.txt"
      OUT_PSCALAR="${DWI_OUT_DIR}/${subj_id}_${ses_id}_${METRIC}.pscalar.nii"
      QC_PNG="${DWI_OUT_DIR}/${subj_id}_${ses_id}_${METRIC}_qc.png"

      if [[ ! -f "${VEC_TXT}" ]]; then
        python3 - <<PY
import csv
tsv="${TSV}"
col="${METRIC}"
out="${VEC_TXT}"
n=1056
vec=[0.0]*n

def parse_float(x):
    if x is None: return None
    x=x.strip()
    if x=="" or x.lower() in ("na","nan","null","none"): return None
    return float(x)

with open(tsv, newline='') as f:
    r=csv.DictReader(f, delimiter="\\t")
    for row in r:
        i=int(row["index"])-1
        v=parse_float(row.get(col,""))
        vec[i]=0.0 if v is None else v

with open(out,"w") as g:
    for v in vec:
        g.write(f"{v}\\n")
PY
      fi

      if [[ ! -f "${OUT_PSCALAR}" ]]; then
        wb_command -cifti-convert -from-text \
          "${VEC_TXT}" \
          "${TEMPLATE_PSCALAR}" \
          "${OUT_PSCALAR}"
      fi

      if [[ ! -f "${QC_PNG}" ]]; then
        singularity exec --cleanenv \
          -B "${DWI_OUT_DIR}:/data" \
          -B "${BASEDIR}/code:/code" \
          -B "${TEMPLATES_DIR}:/templates" \
          -B "${SURF_DIR_SUBJ}:/surf" \
          "${QC_CONTAINER}" \
          python3 /code/noddireg_qc.py \
            --pscalar "/data/$(basename "${OUT_PSCALAR}")" \
            --dlabel  "/templates/tpl-fsLR_res-91k_atlas-4S1056Parcels_dseg.dlabel.nii" \
            --surf-dir "/surf" \
            --out "/data/$(basename "${QC_PNG}")"
      fi
    done
  done
done

## nipoppy trackers

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind "${BASEDIR}:${BASEDIR}" \
  --env SUBJECTS="$SUBJECTS" \
  "${BASEDIR}/containers/nipoppy.sif" /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"

    mkdir -p derivatives/noddireg/0.22.0/output/
    ls -al derivatives/noddireg/0.22.0/output/

    ln -s "$BASEDIR/data/local/derivatives/noddi_reg" derivatives/noddireg/0.22.0/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline noddireg \
        --pipeline-version 0.22.0 \
        --participant-id sub-$subject
    done
  '

