#!/bin/bash
#SBATCH --job-name=extract_to_share_stage3
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=08:00:00
#SBATCH --mem-per-cpu=20000

# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata to

## xcp, xcp-noGSR, tractography, amico-noddi

module load apptainer/1.3.5

PROJECT_DIR=${SLURM_SUBMIT_DIR}


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


if [ -d "${PROJECT_DIR}/data/local/derivatives/xcp_noGSR" ];
then

echo "copying over the xcp_noGSR folder"

## copy over the xcp json files
rm -rf ${PROJECT_DIR}/data/share/xcp_noGSR

## copy over the xcp  folder (all data)
rsync -a ${PROJECT_DIR}/data/local/derivatives/xcp_noGSR  ${PROJECT_DIR}/data/share

else
    echo "No XCP_NO_GSR outputs found."
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





