# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to 

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR=$(dirname "${SCRIPT_DIR}")

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
QSIPREP_SHARE_DIR=${PROJECT_DIR}/data/share/qsiprep
QSIPREP_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/qsiprep/0.21.4/qsiprep

if [ -d "$QSIPREP_LOCAL_DIR" ]; 
then

echo "copying over the qsiprep metadata and qc images"
rsync -a --include "*/" --include="*.json" --exclude="*" ${QSIPREP_LOCAL_DIR} ${QSIPREP_SHARE_DIR}

## copy over the qsiprep html files
subjects=`cd ${QSIPREP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
cp ${QSIPREP_LOCAL_DIR}/*html ${QSIPREP_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${QSIPREP_SHARE_DIR}/${subject}/figures
 rsync -a ${QSIPREP_LOCAL_DIR}/${subject}/figures ${QSIPREP_SHARE_DIR}/${subject}/
done

else

    echo "QSIPREP (DWI) outputs not found"

fi


## run the mriqc group step and copy over all outputs
MRIQC_SHARE_DIR=${PROJECT_DIR}/data/share/mriqc/24.0.0
MRIQC_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/mriqc/24.0.0
export WORK_DIR=${BBUFFER}/SCanD/mriqc

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


if [ -d "${PROJECT_DIR}/data/local/derivatives/xcp_d/0.7.3" ]; 
then

echo "copying over the xcp_d folder"

## copy over the xcp json files 
rm -rf ${PROJECT_DIR}/data/share/xcp_d


## copy over the xcp  folder (all data)
rsync -a ${PROJECT_DIR}/data/local/derivatives/xcp_d  ${PROJECT_DIR}/data/share

else
    echo "No XCP_D outputs found."
fi


if [ -d "${PROJECT_DIR}/data/local/ciftify" ]; 
then

## also run ciftify group step
echo "copying over the ciftify qc images"

## copy over the ciftify QC outputs
rsync -a ${PROJECT_DIR}/data/local/ciftify/qc_recon_all  ${PROJECT_DIR}/data/share/ciftify/

else

    echo "No ciftify outputs found."

fi



## copy over the Enigma_extract outputs
if [ -d "${PROJECT_DIR}/data/local/ENIGMA_extract" ]; 
then
echo "copying over the ENIGMA extracted cortical and subcortical files"
rsync -a ${PROJECT_DIR}/data/local/ENIGMA_extract ${PROJECT_DIR}/data/share/
fi

## copy over the parcellated_ciftify files
if [ -d "${PROJECT_DIR}/data/local/parcellated_ciftify" ]; 
then
echo "copying over the parcellated_ciftify files"
rsync -a ${PROJECT_DIR}/data/local/parcellated_ciftify ${PROJECT_DIR}/data/share/
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



AMICO_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/qsiprep/0.21.4/amico_noddi
AMICO_SHARE_DIR=${PROJECT_DIR}/data/local/amico_noddi

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