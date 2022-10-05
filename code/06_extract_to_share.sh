# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to 

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PROJECT_DIR=$(dirname "${SCRIPT_DIR}")

FMRIPREP_SHARE_DIR=${PROJECT_DIR}/data/share/fmriprep
FMRIPREP_LOCAL_DIR=${PROJECT_DIR}/data/local/fmriprep

mkdir -p ${FMRIPREP_SHARE_DIR}

cp ${FMRIPREP_LOCAL_DIR}/dataset_description.json ${FMRIPREP_SHARE_DIR}/
cp ${FMRIPREP_LOCAL_DIR}/logs ${FMRIPREP_SHARE_DIR}/

subjects=`cd ${FMRIPREP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
cp ${FMRIPREP_LOCAL_DIR}/*html ${FMRIPREP_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${FMRIPREP_SHARE_DIR}/${subject}/figures
 rsync -a ${FMRIPREP_LOCAL_DIR}/${subject}/figures ${FMRIPREP_SHARE_DIR}/${subject}/
done

## also run ciftify group step

singularity run \
    -B ${PROJECT_DIR}/data/local/:/data \
    ${PROJECT_DIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg \
      /data/bids /data group 

rsync -a ${PROJECT_DIR}/data/local/ciftify/qc_recon_all  ${PROJECT_DIR}/data/share/ciftify/
rsync -a ${PROJECT_DIR}/data/local/ciftify/qc_fmri  ${PROJECT_DIR}/data/share/ciftify/

## also run freesurfer ENIGMA scripts

## copy over the freesurfer results
## copy over the ciftify QC outputs
## copy over the parcellated files

## create a spreadsheet output for wether or not outputs were found (each step) for each functional file