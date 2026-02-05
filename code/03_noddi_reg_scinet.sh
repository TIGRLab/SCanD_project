#!/bin/bash

#SBATCH --job-name=noddi_reg
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=02:00:00

set -euo pipefail

SUB_SIZE=1
export THREADS_PER_COMMAND=2
BASEDIR=${SLURM_SUBMIT_DIR}

module load StdEnv/2023
module load connectomeworkbench/2.0.1

# =========================
# PATHS
# =========================
export BIDS_DIR=${BASEDIR}/data/local/bids
export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer
export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep
export NODDI_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI
export CIFTIFY_DIR=${BASEDIR}/data/local/derivatives/ciftify/ciftify_noddi_reg
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/noddi_reg
export TEMPLATES_DIR=${BASEDIR}/templates/parcellations
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SING_CONTAINER=${BASEDIR}/containers/noddi_postproc-v.1.0.simg
export QC_CONTAINER=${BASEDIR}/containers/fmriprep-23.2.3.simg

mkdir -p "${CIFTIFY_DIR}" "${OUTPUT_DIR}"

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

# Fix FS surf naming if needed
for subj in $SUBJECTS_DIR/sub-*; do
  surfdir="$subj/surf"
  [[ -f "$surfdir/lh.pial.T1" ]] && mv "$surfdir/lh.pial.T1" "$surfdir/lh.pial"
  [[ -f "$surfdir/rh.pial.T1" ]] && mv "$surfdir/rh.pial.T1" "$surfdir/rh.pial"
done

############################
# STEP 1: CIFTIFY
############################
for SUBJECT in ${SUBJECTS}; do
  subj_id="sub-${SUBJECT}"
  CIFTIFY_SUBJ_DIR="${CIFTIFY_DIR}/ciftify/${subj_id}"

  if [[ -d "$CIFTIFY_SUBJ_DIR" ]]; then
    echo "Removing existing ciftify output for ${subj_id}"
    rm -rf "$CIFTIFY_SUBJ_DIR"
  fi

  singularity exec --cleanenv \
    -B ${SUBJECTS_DIR}:/freesurfer \
    -B ${CIFTIFY_DIR}:/out \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    ciftify_recon_all \
      --fs-subjects-dir /freesurfer \
      --ciftify-work-dir /out/ciftify \
      --fs-license /li \
      --resample-to-T1w32k \
      --surf-reg FS \
      ${subj_id}

  mkdir -p ${OUTPUT_DIR}/${subj_id}/anat

done

############################
# STEP 2: DLABEL → QSIPREP T1w 
############################
for SUBJECT in ${SUBJECTS}; do
  subj_id="sub-${SUBJECT}"
  mkdir -p ${OUTPUT_DIR}/${subj_id}/anat
  echo "Mapping DLABEL to QSIPrep T1w for ${subj_id}"

  # Ensure QSIPrep T1w is .nii.gz (ciftify script expects nii.gz)
  T1_NII="${QSIPREP_DIR}/${subj_id}/anat/${subj_id}_desc-preproc_T1w.nii"
  T1_GZ="${QSIPREP_DIR}/${subj_id}/anat/${subj_id}_desc-preproc_T1w.nii.gz"
  if [[ ! -f "${T1_GZ}" && -f "${T1_NII}" ]]; then
    echo "[INFO] Creating ${T1_GZ}"
    gzip -c "${T1_NII}" > "${T1_GZ}"
  fi
  [[ -f "${T1_GZ}" ]] || { echo "[ERROR] Missing QSIPrep T1w for ${subj_id}"; exit 1; }

  for parc_file in ${TEMPLATES_DIR}/tpl-fsLR_res-91k_atlas-*_dseg.dlabel.nii; do
    parc_name=$(basename "$parc_file" | sed -E 's/.*atlas-(.*)_dseg\.dlabel\.nii/\1/')

    output_file="${OUTPUT_DIR}/${subj_id}/anat/${subj_id}_space-T1w_desc-${parc_name}_dseg.nii.gz"
    [[ -f "$output_file" ]] && continue

    singularity exec --cleanenv \
      -B ${TEMPLATES_DIR}:/templates \
      -B ${CIFTIFY_DIR}:/out \
      -B ${QSIPREP_DIR}:/qsiprep \
      -B ${OUTPUT_DIR}:/parc \
      -B ${BASEDIR}/code:/code \
      ${SING_CONTAINER} \
      /opt/conda/envs/fmriprep/bin/python /code/ciftify_dlabel_to_vol.py --cortex-only \
        --input-dlabel /templates/$(basename "$parc_file") \
        --left-mid-surface /out/ciftify/${subj_id}/MNINonLinear/fsaverage_LR32k/${subj_id}.L.midthickness.32k_fs_LR.surf.gii \
        --volume-template /qsiprep/${subj_id}/anat/${subj_id}_desc-preproc_T1w.nii.gz \
        --output-nifti /parc/${subj_id}/anat/$(basename "$output_file")
  done
done

############################
# STEP 3: RESAMPLE LABELS TO EACH SESSION'S space-T1w_dwiref GRID
# Write outputs into OUTPUT_DIR/sub-*/ses-*/dwi (session-specific)
# ALSO write "space-ACPC" symlinks into OUTPUT_DIR/sub-*/anat (old behavior)
############################

for SUBJECT in ${SUBJECTS}; do
  subj_id="sub-${SUBJECT}"

  SESSIONS=$(find "${BIDS_DIR}/${subj_id}" -maxdepth 2 -type d -path "*/ses-*/dwi" \
    | sort -V | xargs -n1 dirname | xargs -n1 basename | sed 's/^ses-//')
  [[ -z "${SESSIONS}" ]] && SESSIONS="01"

  echo "Resampling parcellations to dwiref grid for ${subj_id} (sessions: ${SESSIONS})"

  for session in ${SESSIONS}; do
    ses_id="ses-${session}"

    ref_file=$(find "${QSIPREP_DIR}/${subj_id}/${ses_id}/dwi" -name "*_space-T1w_dwiref.nii.gz" | head -n 1)
    [[ -f "${ref_file}" ]] || { echo "[ERROR] Missing dwiref for ${subj_id} ${ses_id}"; exit 1; }

    DWI_OUT_DIR="${OUTPUT_DIR}/${subj_id}/${ses_id}/dwi"
    ANAT_OUT_DIR="${OUTPUT_DIR}/${subj_id}/anat"
    mkdir -p "${DWI_OUT_DIR}" "${ANAT_OUT_DIR}"

    for in_path in ${OUTPUT_DIR}/${subj_id}/anat/${subj_id}_space-T1w_desc-*_dseg.nii.gz; do
      [[ -f "${in_path}" ]] || continue

      base=$(basename "${in_path}")
      desc=$(echo "${base}" | sed -E "s/^${subj_id}_space-T1w_desc-(.*)_dseg\.nii\.gz/\1/")

      out_base="${subj_id}_${ses_id}_space-T1w_ref-dwiref_desc-${desc}_dseg.nii.gz"
      acpc_base="${subj_id}_${ses_id}_space-ACPC_desc-${desc}_dseg.nii.gz"

      singularity exec --cleanenv \
        -B "${QSIPREP_DIR}:/qsiprep" \
        -B "${OUTPUT_DIR}:/parc" \
        "${SING_CONTAINER}" \
        antsApplyTransforms -d 3 \
          -i "/parc/${subj_id}/anat/${base}" \
          -r "/qsiprep/${ref_file#${QSIPREP_DIR}/}" \
          -n GenericLabel \
          -o "/parc/${subj_id}/${ses_id}/dwi/${out_base}"

      ln -sf "../${ses_id}/dwi/${out_base}" "${ANAT_OUT_DIR}/${acpc_base}"

    done
  done
done

# =========================
# STEP 4: METRIC EXTRACTION 
# =========================
cp ${TEMPLATES_DIR}/*dseg.tsv ${OUTPUT_DIR}/

for SUBJECT in ${SUBJECTS}; do
  subj_id="sub-${SUBJECT}"

  SESSIONS=$(find "${BIDS_DIR}/${subj_id}" -maxdepth 2 -type d -path "*/ses-*/dwi" \
    | sort -V | xargs -n1 dirname | xargs -n1 basename | sed 's/^ses-//')
  [[ -z "${SESSIONS}" ]] && SESSIONS="01"

  echo "Extracting noddi metrics for ${subj_id} (sessions: ${SESSIONS})"

  for session in ${SESSIONS}; do
    singularity exec --cleanenv \
      -B "${BASEDIR}/code:/code" \
      -B "${QSIPREP_DIR}:/qsiprep" \
      -B "${NODDI_DIR}:/noddi" \
      -B "${OUTPUT_DIR}:/parc" \
      "${SING_CONTAINER}" \
      /opt/conda/envs/fmriprep/bin/python /code/extract_subject_noddi_metrics_v2.py \
        --subject "${SUBJECT}" \
        --session "${session}" \
        --parc-dir "/parc" \
        --qsiprep-dir "/qsiprep" \
        --amico-noddi-dir "/noddi"
  done
done


############################
# STEP 5: TSV -> PSCALAR + QC PNG (OD / ICVF / ISOVF)
############################

QC_CONTAINER=${BASEDIR}/containers/fmriprep-23.2.3.simg

# one template pscalar per subject
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
    echo "[WARN] Missing ciftify outputs for ${subj_id}, skipping."
    continue
  fi

  # Create subject pscalar template ONCE
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

      # --- QC PNG creation
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

    ln -s "${ROOT_DIR}/data/local/derivatives/noddi_reg" derivatives/noddireg/0.22.0/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline noddireg \
        --pipeline-version 0.22.0 \
        --participant-id sub-$subject
    done
  '
unset APPTAINERENV_ROOT_DIR
