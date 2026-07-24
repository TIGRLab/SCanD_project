#!/bin/bash
#SBATCH --job-name=noddi_fs_parc
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=48:00:00
#SBATCH --mem-per-cpu=4000

set -euo pipefail

BASEDIR=${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}

module load apptainer/1.3.5
module load StdEnv/2023
module load fsl

export BIDS_DIR=${BASEDIR}/data/local/bids
export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4/sourcedata/freesurfer
export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep
export NODDI_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/noddi_reg
export TEMPLATES_DIR=${BASEDIR}/templates/parcellations
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SING_CONTAINER=${BASEDIR}/containers/noddi_postproc-v.1.0.simg
export FREESURFER_DIR=${SUBJECTS_DIR}
export NODDIREG_SHARE_DIR=${BASEDIR}/data/share/noddireg

mkdir -p logs "${OUTPUT_DIR}" "${NODDIREG_SHARE_DIR}"

export_fs_volume_parcellations() {
  local SUBJ="$1"
  local out_dir="${OUTPUT_DIR}/${SUBJ}/anat"
  local pair src_mgz desc out_native

  mkdir -p "${out_dir}"

  for pair in "aparc+aseg:aparcaseg" "wmparc:wmparc"; do
    src_mgz="${pair%%:*}"
    desc="${pair##*:}"
    out_native="${out_dir}/${SUBJ}_space-fsnative_desc-${desc}_dseg.nii.gz"

    [[ -f "${SUBJECTS_DIR}/${SUBJ}/mri/${src_mgz}.mgz" ]] || {
      echo "[ERROR] Missing FreeSurfer volume ${SUBJECTS_DIR}/${SUBJ}/mri/${src_mgz}.mgz"
      exit 1
    }
    echo "[FS] Exporting ${src_mgz}.mgz -> ${out_native}"
    singularity exec --cleanenv \
      -B "${SUBJECTS_DIR}:/freesurfer" \
      -B "${OUTPUT_DIR}:/parc" \
      -B "${ORIG_FS_LICENSE}:/opt/freesurfer/license.txt" \
      "${SING_CONTAINER}" \
      bash -lc "export FREESURFER_HOME=/opt/freesurfer && export FS_LICENSE=/opt/freesurfer/license.txt && \
        mri_convert /freesurfer/${SUBJ}/mri/${src_mgz}.mgz /parc/${SUBJ}/anat/${SUBJ}_space-fsnative_desc-${desc}_dseg.nii.gz"
  done

  [[ -f "${SUBJECTS_DIR}/${SUBJ}/mri/T1.mgz" ]] || {
    echo "[ERROR] Missing ${SUBJECTS_DIR}/${SUBJ}/mri/T1.mgz"
    exit 1
  }
  singularity exec --cleanenv \
    -B "${SUBJECTS_DIR}:/freesurfer" \
    -B "${OUTPUT_DIR}:/parc" \
    -B "${ORIG_FS_LICENSE}:/opt/freesurfer/license.txt" \
    "${SING_CONTAINER}" \
    bash -lc "export FREESURFER_HOME=/opt/freesurfer && export FS_LICENSE=/opt/freesurfer/license.txt && \
      mri_convert /freesurfer/${SUBJ}/mri/T1.mgz /parc/${SUBJ}/anat/${SUBJ}_space-fsnative_T1w.nii.gz"
}

register_fs_parcellations_to_qsiprep() {
  local SUBJ="$1"
  local out_dir="${OUTPUT_DIR}/${SUBJ}/anat"
  local xfm_dir="${out_dir}/xfm_fsT1_to_qsiT1"
  local aff="${xfm_dir}/fs2q_0GenericAffine.mat"
  local desc in_native

  mkdir -p "${xfm_dir}"

  if [[ ! -f "${aff}" ]]; then
    echo "[FS] Computing FreeSurfer T1 -> QSIPrep T1w affine for ${SUBJ}"
    singularity exec --cleanenv \
      -B "${QSIPREP_DIR}:/qsiprep" \
      -B "${OUTPUT_DIR}:/parc" \
      "${SING_CONTAINER}" \
      antsRegistrationSyNQuick.sh -d 3 \
        -f "/qsiprep/${SUBJ}/anat/${SUBJ}_desc-preproc_T1w.nii.gz" \
        -m "/parc/${SUBJ}/anat/${SUBJ}_space-fsnative_T1w.nii.gz" \
        -t a \
        -o "/parc/${SUBJ}/anat/xfm_fsT1_to_qsiT1/fs2q_"
  fi
  [[ -f "${aff}" ]] || { echo "[ERROR] Missing fs2q affine for ${SUBJ}: ${aff}"; exit 1; }

  for desc in wmparc aparcaseg; do
    in_native="${out_dir}/${SUBJ}_space-fsnative_desc-${desc}_dseg.nii.gz"
    [[ -f "${in_native}" ]] || { echo "[ERROR] Missing ${in_native}"; exit 1; }

    echo "[FS] Registering ${desc} to QSIPrep T1w for ${SUBJ}"
    singularity exec --cleanenv \
      -B "${QSIPREP_DIR}:/qsiprep" \
      -B "${OUTPUT_DIR}:/parc" \
      "${SING_CONTAINER}" \
      antsApplyTransforms -d 3 \
        -i "/parc/${SUBJ}/anat/${SUBJ}_space-fsnative_desc-${desc}_dseg.nii.gz" \
        -r "/qsiprep/${SUBJ}/anat/${SUBJ}_desc-preproc_T1w.nii.gz" \
        -t "/parc/${SUBJ}/anat/xfm_fsT1_to_qsiT1/fs2q_0GenericAffine.mat" \
        -n GenericLabel \
        -o "/parc/${SUBJ}/anat/${SUBJ}_space-T1w_desc-${desc}_dseg.nii.gz"
  done
}

sync_wmparc_share() {
  local SUBJ="$1"
  mkdir -p "${NODDIREG_SHARE_DIR}/${SUBJ}"
  find "${OUTPUT_DIR}/${SUBJ}" -type f \( \
    -name "*_desc-wmparc_model-noddi_results.tsv" -o \
    -name "*_desc-aparcaseg_model-noddi_results.tsv" \
  \) -exec rsync -a {} "${NODDIREG_SHARE_DIR}/${SUBJ}/" \;
}

if [[ -n "${SUBJECTS:-}" ]]; then
  :
elif [[ -d "${OUTPUT_DIR}" ]]; then
  SUBJECTS=$(find "${OUTPUT_DIR}" -mindepth 1 -maxdepth 1 -type d -name 'sub-*' \
    | xargs -n1 basename | sed 's/^sub-//' | sort -V | tr '\n' ' ')
else
  echo "[ERROR] No subjects found in ${OUTPUT_DIR}"
  exit 1
fi

echo "[INFO] Re-running FreeSurfer wmparc/aparcaseg for: ${SUBJECTS}"

for SUBJECT in ${SUBJECTS}; do
  SUBJ="sub-${SUBJECT}"

  for d in ${FREESURFER_DIR}/${SUBJ}_ses-*; do
    [[ -e "${d}" ]] || continue
    subj="$(basename "${d%%_ses-*}")"
    ln -sfn "$(basename "${d}")" "${FREESURFER_DIR}/${subj}"
  done

  mkdir -p "${OUTPUT_DIR}/${SUBJ}/anat"

  rm -f "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ciftifyT1_desc-wmparc_dseg.nii.gz" \
        "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ciftifyT1_desc-aparcaseg_dseg.nii.gz" \
        "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_desc-wmparc_dseg.nii.gz" \
        "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_desc-aparcaseg_dseg.nii.gz" \
        "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_ref-dwiref_desc-wmparc_dseg.nii.gz" \
        "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_ref-dwiref_desc-aparcaseg_dseg.nii.gz" \
        "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ACPC_desc-wmparc_dseg.nii.gz" \
        "${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ACPC_desc-aparcaseg_dseg.nii.gz"

  export_fs_volume_parcellations "${SUBJ}"
  register_fs_parcellations_to_qsiprep "${SUBJ}"

  SESSIONS=$(find "${BIDS_DIR}/${SUBJ}" -maxdepth 2 -type d -path "*/ses-*/dwi" \
    | sort -V | xargs -n1 dirname | xargs -n1 basename | sed 's/^ses-//' | tr '\n' ' ')
  [[ -z "${SESSIONS// }" ]] && SESSIONS="01"

  for session in ${SESSIONS}; do
    SES="ses-${session}"
    DWIRREF=$(find "${QSIPREP_DIR}/${SUBJ}/${SES}/dwi" -name "*_space-T1w_dwiref.nii.gz" | head -n 1)
    [[ -f "${DWIRREF}" ]] || { echo "[ERROR] Missing dwiref for ${SUBJ} ${SES}"; exit 1; }

    for desc in wmparc aparcaseg; do
      parc_t1="${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_desc-${desc}_dseg.nii.gz"
      out_dwi="${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-T1w_ref-dwiref_desc-${desc}_dseg.nii.gz"
      parc_acpc="${OUTPUT_DIR}/${SUBJ}/anat/${SUBJ}_space-ACPC_desc-${desc}_dseg.nii.gz"

      flirt -in "${parc_t1}" -ref "${DWIRREF}" \
        -applyxfm -usesqform \
        -interp nearestneighbour \
        -out "${out_dwi}"

      ln -sf "${out_dwi}" "${parc_acpc}"
    done
  done

  cp "${TEMPLATES_DIR}"/*dseg.tsv "${OUTPUT_DIR}/" || true

  for session in ${SESSIONS}; do
    for desc in wmparc aparcaseg; do
      rm -f "${OUTPUT_DIR}/${SUBJ}/ses-${session}/dwi/${SUBJ}_ses-${session}_desc-${desc}_model-noddi_results.tsv"

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
          --amico-noddi-dir "/noddi" \
          --parcellation "${desc}"
    done
  done

  sync_wmparc_share "${SUBJ}"

  python3 - <<PY
import pandas as pd
from pathlib import Path

subj = "${SUBJ}"
ses = "${SESSIONS}".split()[0]
for desc in ["wmparc", "aparcaseg"]:
    tsv = Path("${OUTPUT_DIR}") / subj / f"ses-{ses}" / "dwi" / f"{subj}_ses-{ses}_desc-{desc}_model-noddi_results.tsv"
    if not tsv.exists():
        print(f"[WARN] missing {tsv}")
        continue
    df = pd.read_csv(tsv, sep="\t")
    idx = set(df["index"].astype(int))
    checks = {17: "L-Hippo", 18: "L-Amyg", 53: "R-Hippo", 54: "R-Amyg"}
    present = [name for lab, name in checks.items() if lab in idx]
    print(f"[QC] {subj} {desc}: n_regions={len(df)} subcortical={present}")
PY
done

echo "[DONE] FreeSurfer parcellation rerun complete for ${BASEDIR}"
