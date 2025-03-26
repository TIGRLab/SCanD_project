#!/bin/bash
#SBATCH --job-name=extract_to_share_stage2
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=01:00:00


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata 

## fmriprep, qsiprep, freesurfer, ciftify, tractography, amico-noddi

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


#running freesurfer group merge
echo "Running freesurfer group merge code"
source ${PROJECT_DIR}/code/freesurfer_group_merge.sh

## copy over freesurfer group tsv files
if [ -d "${PROJECT_DIR}/data/local/derivatives/freesurfer/7.4.1/00_group2_stats_tables" ];
then
echo "copying over freesurfer group files"
mkdir ${PROJECT_DIR}/data/share/freesurfer_group
rsync -a ${PROJECT_DIR}/data/local/derivatives/freesurfer/7.4.1/00_group2_stats_tables/*  ${PROJECT_DIR}/data/share/freesurfer_group
rsync -a ${PROJECT_DIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer/00_group2_stats_tables/*  ${PROJECT_DIR}/data/share/freesurfer_group

else

echo "No freesurfer group outputs found."

fi


#running Enigma_extract
echo "Running Enigma Extract"
source ${PROJECT_DIR}/code/ENIGMA_ExtractCortical.sh

## copy over the Enigma_extract outputs
if [ -d "${PROJECT_DIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract" ];
then
echo "copying over the ENIGMA extracted cortical and subcortical files"
rsync -a ${PROJECT_DIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract ${PROJECT_DIR}/data/share/freesurfer_group

else

echo "No ENIGMA_extract outputs found."

fi
