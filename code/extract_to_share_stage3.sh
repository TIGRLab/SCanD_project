#!/bin/bash
#SBATCH --job-name=extract_to_share_stage3
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=08:00:00
#SBATCH --mem-per-cpu=4000

# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

## xcp, xcp-noGSR, noddireg

module load apptainer/1.3.5

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

if [ -d "${NODDIREG_LOCAL_DIR}" ]; then
    echo "Copying noddireg files"

    mkdir -p "${NODDIREG_SHARE_DIR}"

    for subject in $(cd "${NODDIREG_LOCAL_DIR}" && ls -1d sub-*); do
        mkdir -p "${NODDIREG_SHARE_DIR}/${subject}"

        find "${NODDIREG_LOCAL_DIR}/${subject}" \
            -type f \( \
                -path "*/ses-*/dwi/*" -o \
                -path "*/figures/*_desc-dsegtissue_model-noddi_density.png" \
            \) \
            -exec rsync -a {} "${NODDIREG_SHARE_DIR}/${subject}/" \;
    done
else
    echo "No noddireg outputs found."
fi
