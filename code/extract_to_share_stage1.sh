#!/bin/bash
#SBATCH --job-name=extract_to_share_stage1
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=01:00:00


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata 

## mriqc, smriprep, qsiprep 

BASEDIR=${SLURM_SUBMIT_DIR}


## run the smriprep sharing step
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


## run the mriqc group step and copy over all outputs
project_id=$(cat ${BASEDIR}/project_id)
MRIQC_SHARE_DIR=${BASEDIR}/data/share/mriqc/24.0.0
MRIQC_LOCAL_DIR=${BASEDIR}/data/local/derivatives/mriqc/24.0.0
export WORK_DIR=${BBUFFER}/SCanD/${project_id}/mriqc
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
