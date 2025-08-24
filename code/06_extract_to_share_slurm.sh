#!/bin/bash
#SBATCH --job-name=extract_to_share
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=08:00:00
#SBATCH --mem-per-cpu=4000

# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

BASEDIR=${SLURM_SUBMIT_DIR}

module load apptainer/1.3.5

FMRIPREP_SHARE_DIR=${BASEDIR}/data/share/fmriprep/23.2.3
FMRIPREP_LOCAL_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3

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


SMRIPREP_SHARE_DIR=${BASEDIR}/data/share/smriprep/23.2.3/
SMRIPREP_LOCAL_DIR=${BASEDIR}/data/local/derivatives/smriprep/23.2.3/smriprep

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
QSIPREP_SHARE_DIR=${BASEDIR}/data/share/qsiprep/0.22.0
QSIPREP_LOCAL_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep

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
MRIQC_SHARE_DIR=${BASEDIR}/data/share/mriqc/24.0.0
MRIQC_LOCAL_DIR=${BASEDIR}/data/local/derivatives/mriqc/24.0.0
export WORK_DIR=${SLURM_TMPDIR}/SCanD/mriqc
mkdir -p ${WORK_DIR}

if [ -d "$MRIQC_LOCAL_DIR" ];
then

echo "running mriqc group and copying files"
singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/mriqc --home /home/mriqc \
    -B ${BASEDIR}/data/local/bids:/bids \
    -B ${MRIQC_LOCAL_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    ${BASEDIR}/containers/mriqc-24.0.0.simg \
    /bids /derived group \
    -w /work

mkdir -p ${MRIQC_SHARE_DIR}
rsync -a ${MRIQC_LOCAL_DIR}/dataset_description.json ${MRIQC_SHARE_DIR}/
rsync -a ${MRIQC_LOCAL_DIR}/group*.tsv ${MRIQC_SHARE_DIR}/

else

    echo "No MRIQC outputs found."

fi


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



if [ -d "${BASEDIR}/data/local/derivatives/ciftify" ];
then

## also run ciftify group step
echo "copying over the ciftify qc images"

mkdir ${BASEDIR}/data/share/ciftify

singularity exec --cleanenv \
  -B ${BASEDIR}/data/local/bids:/bids \
  -B ${BASEDIR}/data/local/derivatives/ciftify:/derived \
  ${BASEDIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg \
  cifti_vis_recon_all index --ciftify-work-dir /derived


## copy over the ciftify QC outputs
rsync -a ${BASEDIR}/data/local/derivatives/ciftify/qc_recon_all  ${BASEDIR}/data/share/ciftify/

else

    echo "No ciftify outputs found."

fi



## copy over the enigmaDTI files
if [ -d "${BASEDIR}/data/local/enigmaDTI" ];
then
echo "copying over the enigmaDTI files"
mkdir ${BASEDIR}/data/share/enigmaDTI
rsync -a ${BASEDIR}/data/local/enigmaDTI/group*  ${BASEDIR}/data/share/enigmaDTI
rsync -a ${BASEDIR}/data/local/enigmaDTI/*.html  ${BASEDIR}/data/share/enigmaDTI

rsync -a --include "*/" --include "*.png" --exclude "*" ${BASEDIR}/data/local/enigmaDTI/ ${BASEDIR}/data/share/enigmaDTI
fi



AMICO_LOCAL_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi
AMICO_SHARE_DIR=${BASEDIR}/data/share/amico_noddi

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



TRACTIFY_MULTI_LOCAL_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsirecon-MRtrix3_act-HSVS
TRACTIFY_SHARE_DIR=${BASEDIR}/data/share/tractify

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



TRACTIFY_SINGLE_LOCAL_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsirecon-MRtrix3_fork-SS3T_act-HSVS
TRACTIFY_SHARE_DIR=${BASEDIR}/data/share/tractify

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
source ${BASEDIR}/code/freesurfer_group_merge.sh

## copy over freesurfer group tsv files
echo "copying over freesurfer group files"
mkdir ${BASEDIR}/data/share/freesurfer_group
rsync -a ${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/00_group2_stats_tables/*  ${BASEDIR}/data/share/freesurfer_group


#running Enigma_extract
echo "Running Enigma Extract"
source ${BASEDIR}/code/ENIGMA_ExtractCortical.sh

## copy over the Enigma_extract outputs
if [ -d "${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract" ];
then
echo "copying over the ENIGMA extracted cortical and subcortical files"
rsync -a ${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract ${BASEDIR}/data/share/freesurfer_group/
fi


rsync -a --include='noddi_roi/' --include='noddi_roi/**/' --include='noddi_roi/**/*.png' --include='noddi_roi/**/*.csv' --exclude='noddi_roi/**' \
    ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/ \
    ${BASEDIR}/data/share/amico_noddi


## Running aparc, aparc2009s sesction from freesurfer group merge code, cause it doesn't end
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export BIDS_DIR=${BASEDIR}/data/local/bids

# Get subjects from OUTPUT_DIR, remove 'sub-' prefix
SUBJECTS=$(sed -n -E "s/sub-(\S*).*/\1/p" ${BIDS_DIR}/participants.tsv)

singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    /bids /derived group2 \
    --participant_label ${SUBJECTS} \
    --parcellations {aparc,aparc.a2009s}\
    --skip_bids_validator \
    --license_file /li \
    --n_cpus 80

rsync -a ${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/00_group2_stats_tables/*  ${BASEDIR}/data/share/freesurfer_group

cp ${BASEDIR}/Neurobagel/derivatives/processing_status.tsv ${BASEDIR}/data/share/
