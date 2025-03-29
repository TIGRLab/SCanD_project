#!/bin/bash
#SBATCH --job-name=extract_to_share
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=03:00:00


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

PROJECT_DIR=${SLURM_SUBMIT_DIR}

FMRIPREP_SHARE_DIR=${PROJECT_DIR}/data/share/fmriprep/23.2.3
FMRIPREP_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/fmriprep/23.2.3

if [ -d "$FMRIPREP_LOCAL_DIR" ];
then

  echo "Copying FMRIPREP metatdata and QC images"


mkdir -p ${FMRIPREP_SHARE_DIR}

cp ${FMRIPREP_LOCAL_DIR}/dataset_description.json ${FMRIPREP_SHARE_DIR}/
# cp ${FMRIPREP_LOCAL_DIR}/logs ${FMRIPREP_SHARE_DIR}/ permissions not working for this one
cp ${FMRIPREP_LOCAL_DIR}/*dseg.tsv ${FMRIPREP_SHARE_DIR}/ # also grab some anatomical derivatives

subjects=`cd ${FMRIPREP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
cp ${FMRIPREP_LOCAL_DIR}/*html ${FMRIPREP_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${FMRIPREP_SHARE_DIR}/${subject}/figures
 rsync -a ${FMRIPREP_LOCAL_DIR}/${subject}/figures ${FMRIPREP_SHARE_DIR}/${subject}/
done

else

    echo "FMRIPREP outputs not found."

fi


SMRIPREP_SHARE_DIR=${PROJECT_DIR}/data/share/smriprep/23.2.3/
SMRIPREP_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/smriprep/23.2.3/smriprep

if [ -d "$SMRIPREP_LOCAL_DIR" ];
then

  echo "Copying SMRIPREP metatdata and QC images"


mkdir -p ${SMRIPREP_SHARE_DIR}

cp ${SMRIPREP_LOCAL_DIR}/dataset_description.json ${SMRIPREP_SHARE_DIR}/

subjects=`cd ${SMRIPREP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
cp ${SMRIPREP_LOCAL_DIR}/*html ${SMRIPREP_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${SMRIPREP_SHARE_DIR}/${subject}/figures
 rsync -a ${SMRIPREP_LOCAL_DIR}/${subject}/figures ${SMRIPREP_SHARE_DIR}/${subject}/
done

else

    echo "SMRIPREP outputs not found."

fi



## copy over the qsiprep json files (for https://www.nipreps.org/dmriprep-viewer/#/)
QSIPREP_SHARE_DIR=${PROJECT_DIR}/data/share/qsiprep/0.22.0
QSIPREP_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep

if [ -d "$QSIPREP_LOCAL_DIR" ];
then

echo "copying over the qsiprep metadata and qc images"
mkdir -p ${QSIPREP_SHARE_DIR}
rsync -a --include "*/" --include="*.json" --exclude="*" ${QSIPREP_LOCAL_DIR} ${QSIPREP_SHARE_DIR}

## copy over the qsiprep html files
subjects=`cd ${QSIPREP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
find ${QSIPREP_LOCAL_DIR} -name "*.html" -exec cp {} ${QSIPREP_SHARE_DIR}/ \;

for subject in ${subjects}; do
 mkdir -p ${QSIPREP_SHARE_DIR}/${subject}/figures
 rsync -a ${QSIPREP_LOCAL_DIR}/${subject}/figures ${QSIPREP_SHARE_DIR}/${subject}/
done

else

    echo "QSIPREP (DWI) outputs not found"

fi


## run the mriqc group step and copy over all outputs
project_id=$(cat ${PROJECT_DIR}/project_id)
MRIQC_SHARE_DIR=${PROJECT_DIR}/data/share/mriqc/24.0.0
MRIQC_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/mriqc/24.0.0
export WORK_DIR=${BBUFFER}/SCanD/${project_id}/mriqc
mkdir -vp ${WORK_DIR}

if [ -d "$MRIQC_LOCAL_DIR" ];
then

echo "running mriqc group and copying files"
singularity run --cleanenv \
    -B ${PROJECT_DIR}/templates:/home/mriqc --home /home/mriqc \
    -B ${PROJECT_DIR}/data/local/bids:/bids \
    -B ${MRIQC_LOCAL_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    ${PROJECT_DIR}/containers/mriqc-24.0.0.simg \
    /bids /derived group \
    -w /work

mkdir -p ${MRIQC_SHARE_DIR}
rsync -a ${MRIQC_LOCAL_DIR}/dataset_description.json ${MRIQC_SHARE_DIR}/
rsync -a ${MRIQC_LOCAL_DIR}/group*.tsv ${MRIQC_SHARE_DIR}/

else

    echo "No MRIQC outputs found."

fi


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



if [ -d "${PROJECT_DIR}/data/local/derivatives/ciftify" ];
then

## also run ciftify group step
echo "copying over the ciftify qc images"

mkdir ${PROJECT_DIR}/data/share/ciftify

singularity exec --cleanenv \
  -B ${PROJECT_DIR}/data/local/bids:/bids \
  -B ${PROJECT_DIR}/data/local/derivatives/ciftify:/derived \
  ${PROJECT_DIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg \
  cifti_vis_recon_all index --ciftify-work-dir /derived


## copy over the ciftify QC outputs
rsync -a ${PROJECT_DIR}/data/local/derivatives/ciftify/qc_recon_all  ${PROJECT_DIR}/data/share/ciftify/

else

    echo "No ciftify outputs found."

fi



## copy over the enigmaDTI files
if [ -d "${PROJECT_DIR}/data/local/enigmaDTI" ];
then
echo "copying over the enigmaDTI files"
mkdir ${PROJECT_DIR}/data/share/enigmaDTI
rsync -a ${PROJECT_DIR}/data/local/enigmaDTI/group*  ${PROJECT_DIR}/data/share/enigmaDTI
rsync -a ${PROJECT_DIR}/data/local/enigmaDTI/*.html  ${PROJECT_DIR}/data/share/enigmaDTI

rsync -a --include "*/" --include "*.png" --exclude "*" ${PROJECT_DIR}/data/local/enigmaDTI/ ${PROJECT_DIR}/data/share/enigmaDTI
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


#running freesurfer group merge
source ${PROJECT_DIR}/code/freesurfer_group_merge.sh

## copy over freesurfer group tsv files
echo "copying over freesurfer group files"
mkdir ${PROJECT_DIR}/data/share/freesurfer_group
rsync -a ${PROJECT_DIR}/data/local/derivatives/freesurfer/7.4.1/00_group2_stats_tables/*  ${PROJECT_DIR}/data/share/freesurfer_group
rsync -a ${PROJECT_DIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer/00_group2_stats_tables/*  ${PROJECT_DIR}/data/share/freesurfer_group


#running Enigma_extract
echo "Running Enigma Extract"
source ${PROJECT_DIR}/code/ENIGMA_ExtractCortical.sh

## copy over the Enigma_extract outputs
if [ -d "${PROJECT_DIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract" ];
then
echo "copying over the ENIGMA extracted cortical and subcortical files"
rsync -a ${PROJECT_DIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract ${PROJECT_DIR}/data/share/freesurfer_group
fi


rsync -a --include='noddi_roi/' --include='noddi_roi/**/' --include='noddi_roi/**/*.png' --include='noddi_roi/**/*.csv' --exclude='noddi_roi/**' \
    ${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/ \
    ${PROJECT_DIR}/data/share/amico_noddi
