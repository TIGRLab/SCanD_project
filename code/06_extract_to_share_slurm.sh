#!/bin/bash
#SBATCH --job-name=extract_to_share
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=03:00:00


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

BASEDIR=${SLURM_SUBMIT_DIR}

FMRIPREP_SHARE_DIR=${BASEDIR}/data/share/fmriprep/25.2.4
FMRIPREP_LOCAL_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4
FREESURFER_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4/sourcedata/freesurfer

# Create subject-only symlinks (remove _ses* suffix)
for d in ${FREESURFER_DIR}/sub-*_ses-*; do
  subj="${d%%_ses-*}"      # strips _ses-XX
  ln -sfn "$d" "$subj"
done

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
 rsync -zarv ${FMRIPREP_LOCAL_DIR}/${subject}/figures ${FMRIPREP_SHARE_DIR}/${subject}/
 rsync -zarvR ${FMRIPREP_LOCAL_DIR}/./sourcedata/freesurfer/${subject}/scripts/recon-all-status.log ${FMRIPREP_SHARE_DIR}/
done

else

    echo "FMRIPREP outputs not found."

fi


SMRIPREP_SHARE_DIR=${BASEDIR}/data/share/smriprep/25.2.4/
SMRIPREP_LOCAL_DIR=${BASEDIR}/data/local/derivatives/smriprep/25.2.4/smriprep

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
mkdir -vp ${WORK_DIR}

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



TRACTIFY_MULTI_LOCAL_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/tractography/qsirecon-MRtrix3_act-HSVS
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



TRACTIFY_SINGLE_LOCAL_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/tractography/qsirecon-MRtrix3_fork-SS3T_act-HSVS
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
rsync -a ${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract ${BASEDIR}/data/share/freesurfer_group
fi


rsync -a --include='noddi_roi/' --include='noddi_roi/**/' --include='noddi_roi/**/*.png' --include='noddi_roi/**/*.csv' --exclude='noddi_roi/**' \
    ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/ \
    ${BASEDIR}/data/share/amico_noddi


#running Noddi-registration
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

# sharing nipoppy trackers
cp "$(ls -t ${BASEDIR}/Neurobagel/derivatives/.processing_statuses/processing_status-*.tsv | head -n 1)" data/share/processing_status.tsv
cp "$(ls -t ${BASEDIR}/Neurobagel/.manifests/manifest*.tsv | head -n 1)" data/share/manifest.tsv
cp ${BASEDIR}/Neurobagel/derivatives/processing_status_fmriprep.tsv  ${BASEDIR}/data/share
cp ${BASEDIR}/Neurobagel/derivatives/processing_status_qsiprep.tsv  ${BASEDIR}/data/share

cp ${BASEDIR}/data/local/bids/participants.tsv ${BASEDIR}/data/share

# Copy GLM outputs to shared folder
GLM_SHARE_DIR=${BASEDIR}/data/share/glm/0.0.1
GLM_LOCAL_DIR=${BASEDIR}/data/local/derivatives/glm/0.0.1
mkdir -p ${GLM_SHARE_DIR}
if [ -d "$GLM_LOCAL_DIR" ];
then
    echo "Copying GLM outputs, metadata, and QC images"
    # Copying the metadata json
    subjects=`cd ${GLM_LOCAL_DIR}; ls -1d sub-*`
    
    echo for subject in ${subjects}; do
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