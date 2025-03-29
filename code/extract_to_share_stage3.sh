#!/bin/bash
#SBATCH --job-name=extract_to_share_stage3
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=08:00:00


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

## xcp, xcp-noGSR, tractography, amico-noddi

PROJECT_DIR=${SLURM_SUBMIT_DIR}

if [ -d "${PROJECT_DIR}/data/local/derivatives/xcp_d/0.7.3" ]; then
    echo "Copying over the xcp_d folder"

    rsync -a \
        --exclude '*/sub-*/ses-*/anat/' \
        --exclude '*/sub-*/ses-*/func/*pearsoncorrelation*' \
        --exclude '*/sub-*/anat/' \
        --exclude '*/sub-*/log/' \
        --exclude '*/sub-*/func/*pearsoncorrelation*' \
        --exclude '*/atlases/' \
        --exclude '*/logs/' \
        ${PROJECT_DIR}/data/local/derivatives/xcp_d ${PROJECT_DIR}/data/share

    mkdir -p ${PROJECT_DIR}/data/share/xcp_d/0.7.3/dtseries

    BASE="${PROJECT_DIR}/data/share/xcp_d/0.7.3"

    for sub_dir in ${BASE_DIR}/sub-*; do
        if [ -d "$sub_dir" ]; then
            subject_id=$(basename "$sub_dir")
            
            mkdir -p "${BASE_DIR}/dtseries/${subject_id}"
            ses_dirs=$(find "$sub_dir" -type d -name "ses-*")
            
            if [ -z "$ses_dirs" ]; then
                # If no ses-* directories, move dtseries.nii files directly from func/
                for dtfile in ${sub_dir}/func/*dtseries.nii; do
                    if [ -f "$dtfile" ]; then
                        mv "$dtfile" "${BASE_DIR}/dtseries/${subject_id}/"
                    fi
                done
            else
                # If ses-* directories exist, loop over them and move dtseries.nii files
                for ses_dir in ${sub_dir}/ses-*; do
                    for dtfile in ${ses_dir}/func/*dtseries.nii; do
                        if [ -f "$dtfile" ]; then
                            mv "$dtfile" "${BASE_DIR}/dtseries/${subject_id}/"
                        fi
                    done
                done
            fi
        fi
    done

else
    echo "No XCP_D outputs found."
fi



if [ -d "${PROJECT_DIR}/data/local/derivatives/xcp_noGSR/" ]; then
    echo "Copying over the xcp_noGSR folder"

    rsync -a \
        --exclude '*/sub-*/ses-*/anat/' \
        --exclude '*/sub-*/ses-*/func/*pearsoncorrelation*' \
        --exclude '*/sub-*/anat/' \
        --exclude '*/sub-*/log/' \
        --exclude '*/sub-*/func/*pearsoncorrelation*' \
        --exclude '*/atlases/' \
        --exclude '*/logs/' \
        ${PROJECT_DIR}/data/local/derivatives/xcp_noGSR ${PROJECT_DIR}/data/share

    mkdir -p ${PROJECT_DIR}/data/share/xcp_noGSR/dtseries

    BASE="${PROJECT_DIR}/data/share/xcp_noGSR"

    for sub_dir in ${BASE_DIR}/sub-*; do
        if [ -d "$sub_dir" ]; then
            subject_id=$(basename "$sub_dir")
            
            mkdir -p "${BASE_DIR}/dtseries/${subject_id}"
            ses_dirs=$(find "$sub_dir" -type d -name "ses-*")
            
            if [ -z "$ses_dirs" ]; then
                # If no ses-* directories, move dtseries.nii files directly from func/
                for dtfile in ${sub_dir}/func/*dtseries.nii; do
                    if [ -f "$dtfile" ]; then
                        mv "$dtfile" "${BASE_DIR}/dtseries/${subject_id}/"
                    fi
                done
            else
                # If ses-* directories exist, loop over them and move dtseries.nii files
                for ses_dir in ${sub_dir}/ses-*; do
                    for dtfile in ${ses_dir}/func/*dtseries.nii; do
                        if [ -f "$dtfile" ]; then
                            mv "$dtfile" "${BASE_DIR}/dtseries/${subject_id}/"
                        fi
                    done
                done
            fi
        fi
    done

else
    echo "No XCP_noGSR outputs found."
fi



TRACTIFY_MULTI_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/qsirecon-MRtrix3_act-HSVS
TRACTIFY_SHARE_DIR=${PROJECT_DIR}/data/share/tractify

if [ -d "${TRACTIFY_MULTI_LOCAL_DIR}" ];
then
echo "copying over the tractify multi-shell connectivity file"

## copy over the tractify mat file
subjects=`cd ${TRACTIFY_MULTI_LOCAL_DIR}; ls -1d sub-*`
mkdir ${TRACTIFY_SHARE_DIR}
for subject in ${subjects}; do
 mkdir -p ${TRACTIFY_SHARE_DIR}/${subject}
 find ${TRACTIFY_MULTI_LOCAL_DIR}/${subject} -type f -name '*connectivity.mat' -exec rsync -a {} ${TRACTIFY_SHARE_DIR}/${subject}/ \;
done

else

echo "No TRACTIFY multi-shell outputs found."

fi



TRACTIFY_SINGLE_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/qsirecon-MRtrix3_fork-SS3T_act-HSVS
TRACTIFY_SHARE_DIR=${PROJECT_DIR}/data/share/tractify

if [ -d "${TRACTIFY_SINGLE_LOCAL_DIR}" ];
then
echo "copying over the tractify single-shell connectivity file"

## copy over the tractify mat file
subjects=`cd ${TRACTIFY_SINGLE_LOCAL_DIR}; ls -1d sub-*`
mkdir ${TRACTIFY_SHARE_DIR}
for subject in ${subjects}; do
 mkdir -p ${TRACTIFY_SHARE_DIR}/${subject}
 find ${TRACTIFY_SINGLE_LOCAL_DIR}/${subject} -type f -name '*connectivity.mat' -exec rsync -a {} ${TRACTIFY_SHARE_DIR}/${subject}/ \;
done

else

echo "No TRACTIFY single-shell outputs found."

fi


AMICO_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi
AMICO_SHARE_DIR=${PROJECT_DIR}/data/share/amico_noddi

if [ -d "${AMICO_LOCAL_DIR}" ];
then
echo "copying over the amico noddi metadata and qc images"

## copy over the amico noddi html files
subjects=`cd ${AMICO_LOCAL_DIR}/qsirecon-NODDI; ls -1d sub-* | grep -v html`
mkdir ${AMICO_SHARE_DIR}
cp ${AMICO_LOCAL_DIR}/qsirecon-NODDI/*html ${AMICO_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${AMICO_SHARE_DIR}/${subject}/figures
 rsync -a ${AMICO_LOCAL_DIR}/qsirecon-NODDI/${subject}/figures ${AMICO_SHARE_DIR}/${subject}/
done

else

echo "No NODDI outputs found."

fi


