# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to 

echo "copying over the fmriprep metadata and qc images"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR=$(dirname "${SCRIPT_DIR}")

FMRIPREP_SHARE_DIR=${PROJECT_DIR}/data/share/fmriprep
FMRIPREP_LOCAL_DIR=${PROJECT_DIR}/data/local/fmriprep

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


echo "copying over the qsiprep metadata and qc images"
## copy over the qsiprep json files (for https://www.nipreps.org/dmriprep-viewer/#/)
QSIPREP_SHARE_DIR=${PROJECT_DIR}/data/share/qsiprep
QSIPREP_LOCAL_DIR=${PROJECT_DIR}/data/local/qsiprep

rsync -a --include "*/" --include="*.json" --exclude="*" ${QSIPREP_LOCAL_DIR} ${QSIPREP_SHARE_DIR}

## copy over the qsiprep html files
subjects=`cd ${QSIPREP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
cp ${QSIPREP_LOCAL_DIR}/*html ${QSIPREP_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${QSIPREP_SHARE_DIR}/${subject}/figures
 rsync -a ${QSIPREP_LOCAL_DIR}/${subject}/figures ${QSIPREP_SHARE_DIR}/${subject}/
done


## run the mriqc group step and copy over all outputs
echo "running mriqc group and copying files"
singularity run --cleanenv \
    -B ${PROJECT_DIR}/templates:/home/mriqc --home /home/mriqc \
    -B ${PROJECT_DIR}/data/local/bids:/bids \
    -B ${PROJECT_DIR}/data/local/mriqc:/derived \
    ${PROJECT_DIR}/containers/mriqc-22.0.6.simg \
    /bids /derived group 

mkdir ${PROJECT_DIR}/data/share/mriqc
rsync -a ${PROJECT_DIR}/data/local/mriqc/dataset_description.json ${PROJECT_DIR}/data/share/mriqc/
rsync -a ${PROJECT_DIR}/data/local/mriqc/group*.tsv ${PROJECT_DIR}/data/share/mriqc/


echo "copying over the xcp_d metadata and qc images"

## copy over the xcp json files 
XCP_SHARE_DIR=${PROJECT_DIR}/data/share/xcp_d
XCP_LOCAL_DIR=${PROJECT_DIR}/data/local/xcp_d

mkdir ${XCP_SHARE_DIR}

rsync -a --include "*/" --include="*.json" --exclude="*" ${XCP_LOCAL_DIR} ${XCP_SHARE_DIR}

## copy over the xcp html files
subjects=`cd ${XCP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
cp ${XCP_LOCAL_DIR}/*html ${XCP_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${XCP_SHARE_DIR}/${subject}/figures
 rsync -a ${XCP_LOCAL_DIR}/${subject}/figures ${XCP_SHARE_DIR}/${subject}/
done

## also run ciftify group step
echo "copying over the ciftify qc images"

## copy over the ciftify QC outputs
rsync -a ${PROJECT_DIR}/data/local/ciftify/qc_recon_all  ${PROJECT_DIR}/data/share/ciftify/


## copy over the parcellated files
echo "copying over the parcellated files"
rsync -a ${PROJECT_DIR}/data/local/parcellated ${PROJECT_DIR}/data/share/




## copy over the Enigma_extract outputs
echo "copying over the ENIGMA extracted cortical and subcortical files"
rsync -a ${PROJECT_DIR}/data/local/ENIGMA_extract ${PROJECT_DIR}/data/share/

