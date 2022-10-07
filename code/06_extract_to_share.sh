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
cp ${FMRIPREP_LOCAL_DIR}/logs ${FMRIPREP_SHARE_DIR}/
cp ${FMRIPREP_LOCAL_DIR}/*dseg.tsv ${FMRIPREP_SHARE_DIR}/ # also grab some anatomical derivatives

subjects=`cd ${FMRIPREP_LOCAL_DIR}; ls -1d sub-* | grep -v html`
cp ${FMRIPREP_LOCAL_DIR}/*html ${FMRIPREP_SHARE_DIR}/
for subject in ${subjects}; do
 mkdir -p ${FMRIPREP_SHARE_DIR}/${subject}/figures
 rsync -a ${FMRIPREP_LOCAL_DIR}/${subject}/figures ${FMRIPREP_SHARE_DIR}/${subject}/
done

## also run ciftify group step
echo "copying over the ciftify qc images"

singularity run \
    -B ${PROJECT_DIR}/data/local/:/data \
    ${PROJECT_DIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg \
      /data/bids /data group 

## copy over the ciftify QC outputs
rsync -a ${PROJECT_DIR}/data/local/ciftify/qc_recon_all  ${PROJECT_DIR}/data/share/ciftify/
rsync -a ${PROJECT_DIR}/data/local/ciftify/qc_fmri  ${PROJECT_DIR}/data/share/ciftify/

## also run ciftify group step - on the cleaned RSN maps

singularity exec \
  -B ${PROJECT_DIR}/data/local:/derived \
  ${PROJECT_DIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg \
  cifti_vis_RSN index \
  --qcdir /derived/cifti_clean/qc_rsn \
  --ciftify-work-dir /derived/ciftify 

## copy over the ciftify QC outputs
echo "copying over the resting state images from cleaned images"
rsync -a ${PROJECT_DIR}/data/local/cifti_clean/qc_rsn ${PROJECT_DIR}/data/share/cifti_clean

## also run freesurfer ENIGMA scripts

## copy over the freesurfer results

## copy over the parcellated files
echo "copying over the parcellated files"
rsync -a ${PROJECT_DIR}/data/local/parcellated ${PROJECT_DIR}/data/share/

## create a spreadsheet output for wether or not outputs were found (each step) for each functional file

## zip all the outputs for transfer ?

## run the mriqc group step and copy over all outputs
echo "running mriqc group and copying files"
singularity run --cleanenv \
    -B ${PROJECT_DIR}/templates:/home/mriqc --home /home/mriqc \
    -B ${PROJECT_DIR}/data/local/bids:/bids \
    -B ${PROJECT_DIR}/data/local/mriqc:/derived \
    ${PROJECT_DIR}/containers/mriqc-22.0.6.simg \
    /bids /derived group 

rsync -a ${PROJECT_DIR}/data/local/mriqc/dataset_description.json ${PROJECT_DIR}/data/share/mriqc
rsync -a ${PROJECT_DIR}/data/local/mriqc/group*.tsv ${PROJECT_DIR}/data/share/mriqc
