#!/bin/bash
#SBATCH --job-name=extract_to_share_stage2
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00
#SBATCH --mem-per-cpu=4000


# A script to extract the bits that we want to share back with the corsotium
# meant to just be run one time after the other pipelines are run

## copying the fmriprep QA files and figures plus logs and metadata 

## fmriprep, freesurfer, ciftify, tractography, amico-noddi

module load apptainer/1.3.5

BASEDIR=${SLURM_SUBMIT_DIR}


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


#running Enigma_extract
echo "Running Enigma Extract"
source ${BASEDIR}/code/ENIGMA_ExtractCortical.sh

## copy over the Enigma_extract outputs
if [ -d "${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract" ];
then
echo "copying over the ENIGMA extracted cortical and subcortical files"
rsync -a ${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/ENIGMA_extract ${BASEDIR}/data/share/freesurfer_group

else

echo "No ENIGMA_extract outputs found."

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



#running freesurfer group merge
echo "Running freesurfer group merge code"
source ${BASEDIR}/code/freesurfer_group_merge.sh

## copy over freesurfer group tsv files
if [ -d "${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/00_group2_stats_tables" ];
then
echo "copying over freesurfer group files"
mkdir ${BASEDIR}/data/share/freesurfer_group
rsync -a ${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/00_group2_stats_tables/*  ${BASEDIR}/data/share/freesurfer_group
else

echo "No freesurfer group outputs found."

fi



## Running aparc, aparc2009s sesction from freesurfer group merge code, cause it doesn't end
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export BIDS_DIR=${BASEDIR}/data/local/bids

# Get subjects from OUTPUT_DIR, remove 'sub-' prefix
SUBJECTS=$(find ${OUTPUT_DIR} -maxdepth 1 -type d -name "sub-*" | sed -E 's|.*/sub-||' | sort)

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
