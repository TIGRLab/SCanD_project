#!/bin/bash
#SBATCH --job-name=extract_to_share_stage1
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=2000


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata 

## mriqc, smriprep 


module load apptainer/1.3.5

PROJECT_DIR=${SLURM_SUBMIT_DIR}


## run the smriprep sharing step
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


## run the mriqc group step and copy over all outputs
project_id=$(cat ${PROJECT_DIR}/project_id)
MRIQC_SHARE_DIR=${PROJECT_DIR}/data/share/mriqc/24.0.0
MRIQC_LOCAL_DIR=${PROJECT_DIR}/data/local/derivatives/mriqc/24.0.0
export WORK_DIR=${SLURM_TMPDIR}/SCanD/mriqc
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
