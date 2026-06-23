#!/bin/bash
#SBATCH --job-name=extract_to_share_stage3
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=08:00:00


# A script to extract the bits that we want to share back with the consortium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

## xcp, xcp-noGSR, noddireg

BASEDIR=${SLURM_SUBMIT_DIR}

if [ -d "${BASEDIR}/data/local/derivatives/xcp_d/0.7.3" ]; then
    echo "Copying over the xcp_d folder"

    rsync -a \
        --exclude '*/sub-*/ses-*/anat/' \
        --exclude '*/sub-*/ses-*/func/*pearsoncorrelation*' \
        --exclude '*/sub-*/anat/' \
        --exclude '*/sub-*/log/' \
        --exclude '*/sub-*/func/*pearsoncorrelation*' \
        --exclude '*/atlases/' \
        --exclude '*/logs/' \
        ${BASEDIR}/data/local/derivatives/xcp_d ${BASEDIR}/data/share

    mkdir -p ${BASEDIR}/data/share/xcp_d/0.7.3/dtseries

    BASE="${BASEDIR}/data/share/xcp_d/0.7.3"

    for sub_dir in ${BASE}/sub-*; do
        if [ -d "$sub_dir" ]; then
            subject_id=$(basename "$sub_dir")
            
            mkdir -p "${BASE}/dtseries/${subject_id}"
            ses_dirs=$(find "$sub_dir" -type d -name "ses-*")
            
            if [ -z "$ses_dirs" ]; then
                # If no ses-* directories, move dtseries.nii files directly from func/
                for dtfile in ${sub_dir}/func/*dtseries.nii; do
                    if [ -f "$dtfile" ]; then
                        mv "$dtfile" "${BASE}/dtseries/${subject_id}/"
                    fi
                done
            else
                # If ses-* directories exist, loop over them and move dtseries.nii files
                for ses_dir in ${sub_dir}/ses-*; do
                    for dtfile in ${ses_dir}/func/*dtseries.nii; do
                        if [ -f "$dtfile" ]; then
                            mv "$dtfile" "${BASE}/dtseries/${subject_id}/"
                        fi
                    done
                done
            fi
        fi
    done

else
    echo "No XCP_D outputs found."
fi



if [ -d "${BASEDIR}/data/local/derivatives/xcp_noGSR/" ]; then
    echo "Copying over the xcp_noGSR folder"

    rsync -a \
        --exclude '*/sub-*/ses-*/anat/' \
        --exclude '*/sub-*/ses-*/func/*pearsoncorrelation*' \
        --exclude '*/sub-*/anat/' \
        --exclude '*/sub-*/log/' \
        --exclude '*/sub-*/func/*pearsoncorrelation*' \
        --exclude '*/atlases/' \
        --exclude '*/logs/' \
        ${BASEDIR}/data/local/derivatives/xcp_noGSR ${BASEDIR}/data/share

    mkdir -p ${BASEDIR}/data/share/xcp_noGSR/dtseries

    BASE="${BASEDIR}/data/share/xcp_noGSR"

    for sub_dir in ${BASE}/sub-*; do
        if [ -d "$sub_dir" ]; then
            subject_id=$(basename "$sub_dir")
            
            mkdir -p "${BASE}/dtseries/${subject_id}"
            ses_dirs=$(find "$sub_dir" -type d -name "ses-*")
            
            if [ -z "$ses_dirs" ]; then
                # If no ses-* directories, move dtseries.nii files directly from func/
                for dtfile in ${sub_dir}/func/*dtseries.nii; do
                    if [ -f "$dtfile" ]; then
                        mv "$dtfile" "${BASE}/dtseries/${subject_id}/"
                    fi
                done
            else
                # If ses-* directories exist, loop over them and move dtseries.nii files
                for ses_dir in ${sub_dir}/ses-*; do
                    for dtfile in ${ses_dir}/func/*dtseries.nii; do
                        if [ -f "$dtfile" ]; then
                            mv "$dtfile" "${BASE}/dtseries/${subject_id}/"
                        fi
                    done
                done
            fi
        fi
    done

else
    echo "No XCP_noGSR outputs found."
fi


NODDIREG_LOCAL_DIR="${BASEDIR}/data/local/derivatives/noddi_reg"
NODDIREG_SHARE_DIR="${BASEDIR}/data/share/noddireg"
QSIPREP_LOCAL_DIR="${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep"
NODDI_QC_PARC="4S1056Parcels"

if [ -d "${NODDIREG_LOCAL_DIR}" ]; then
    echo "Copying noddireg files"

    mkdir -p "${NODDIREG_SHARE_DIR}"

    for subject in $(cd "${NODDIREG_LOCAL_DIR}" && ls -1d sub-*); do
        mkdir -p "${NODDIREG_SHARE_DIR}/${subject}/figures"

        find "${NODDIREG_LOCAL_DIR}/${subject}" \
            -type f \( \
                -path "*/ses-*/dwi/*" -o \
                -path "*/figures/*_desc-dsegtissue_model-noddi_density.png" -o \
                -path "*/figures/*_desc-${NODDI_QC_PARC}_model-noddi_mdp-*_qa.png" \
            \) | while IFS= read -r qc_file; do
            if [[ "${qc_file}" == *.png ]]; then
                rsync -a "${qc_file}" "${NODDIREG_SHARE_DIR}/${subject}/figures/"
            else
                rsync -a "${qc_file}" "${NODDIREG_SHARE_DIR}/${subject}/"
            fi
        done

        LAST_SES_DIR=$(find "${QSIPREP_LOCAL_DIR}/${subject}" -maxdepth 1 -type d -name "ses-*" | sort -V | tail -n 1)
        if [ -n "${LAST_SES_DIR}" ]; then
            DWIREF=$(find "${LAST_SES_DIR}/dwi" -maxdepth 1 -type f -name "*_space-T1w_dwiref.nii.gz" | head -n 1)
            if [ -f "${DWIREF}" ]; then
                rsync -a "${DWIREF}" "${NODDIREG_SHARE_DIR}/${subject}/"
            else
                echo "[WARN] Missing dwiref for ${subject} in ${LAST_SES_DIR}"
            fi
        else
            echo "[WARN] No qsiprep sessions found for ${subject}"
        fi

        PARC_FILE="${NODDIREG_LOCAL_DIR}/${subject}/anat/${subject}_space-T1w_ref-dwiref_desc-${NODDI_QC_PARC}_dseg.nii.gz"
        if [ -f "${PARC_FILE}" ]; then
            rsync -a "${PARC_FILE}" "${NODDIREG_SHARE_DIR}/${subject}/"
        else
            echo "[WARN] Missing parcellation ${PARC_FILE}"
        fi
    done
else
    echo "No noddireg outputs found."
fi


# Copy GLM outputs to shared folder
GLM_SHARE_DIR=${BASEDIR}/data/share/glm/0.0.1
GLM_LOCAL_DIR=${BASEDIR}/data/local/derivatives/glm/0.0.1

if [ -d "$GLM_LOCAL_DIR" ];
then
    echo "Copying GLM outputs, metadata, and QC images"
    # Copying the metadata json
    mkdir -p ${GLM_SHARE_DIR}
    subjects=`cd ${GLM_LOCAL_DIR}; ls -1d sub-*`
    for subject in ${subjects}; do
        GLM_SUB_SHARE_DIR=${GLM_SHARE_DIR}/${subject}
        GLM_SUB_LOCAL_DIR=${GLM_LOCAL_DIR}/${subject}
        mkdir -p ${GLM_SUB_SHARE_DIR}
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*glm.json ${GLM_SUB_SHARE_DIR}/
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*design.svg ${GLM_SUB_SHARE_DIR}/
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*design.tsv ${GLM_SUB_SHARE_DIR}/
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*contrast-*_stat-*statmap.dscalar.nii ${GLM_SUB_SHARE_DIR}/
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*contrast-*_stat-*statmap.png ${GLM_SUB_SHARE_DIR}/
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*residuals.dtseries.nii ${GLM_SUB_SHARE_DIR}/

        if compgen -G "${GLM_SUB_LOCAL_DIR}/*fixedeffects.json" > /dev/null; then
        echo "Copying fixed-effect outputs"
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*fixedeffects.json ${GLM_SUB_SHARE_DIR}/
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*fixed*.dscalar.nii ${GLM_SUB_SHARE_DIR}/
        rsync -zarv ${GLM_SUB_LOCAL_DIR}/*fixed*.png ${GLM_SUB_SHARE_DIR}/
        fi
    done
else
    echo "GLM outputs not found."
fi

