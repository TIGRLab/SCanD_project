#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=80
#SBATCH --time=00:20:00
#SBATCH --job-name="cifti_clean"
#SBATCH --output=logs/cifti_clean_%j.txt

## set the second environment variable to get the base directory
BASEDIR=${SLURM_SUBMIT_DIR}

## this script requires gnu-parallel
module load gnu-parallel/20191122

## this assumes that this repo is cloned into the place it's supposed to be (according ot the README)
export CODEDIR=${BASEDIR}/code
echo "the CODEDIR is $CODEDIR"
export clean_config=cleaning_settings.json

export SMOOTHING_FWHM=0

## set up a trap that will clear the ramdisk if it is not cleared
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

#trap the termination signal, and call the function 'trap_term' when
# that happens, so results may be saved.
trap "cleanup_ramdisk" TERM

# input is BIDS_DIR this is where the data downloaded from openneuro went
export BIDS_DIR=${BASEDIR}/data/local/bids

## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export SING_CONTAINER=${BASEDIR}/containers/fmriprep_ciftity-v1.3.2-2.3.3.simg


## setting up the output folders
export DERIVED_DIR=${BASEDIR}/data/local

# mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} ${LOGS_DIR} # ${LOCAL_FREESURFER_DIR}

fmriprep_folder=${DERIVED_DIR}/fmriprep
ciftify_folder=${DERIVED_DIR}/ciftify

## get the subject list from a combo of the array id, the participants.tsv and the chunk size
SUB_SIZE=10 ## number of subjects to run
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

## using bash fancyness to pull a subset of the outputs based on the slurm array id
ALL_DTSERIES=$(ls -1d ${DERIVED_DIR}/ciftify/sub*/MNINonLinear/Results/*task*/*dtseries*)
THESE_DTSERIES=`for dt in ${ALL_DTSERIES}; do echo $dt; done | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`

# building a function that runs the cleaning steps
run_cleaning_script() {

    dtseries=${1}

    # build a temp dir to serve as the singularity home 
    # we need this because wb_command will put a lock here to prevent multiple jobs
    sing_home=$(mktemp -d -t wb-XXXXXXXXXX)

    # determine the output filenames based on the input filename
    func_base=$(basename $(dirname ${dtseries}))
    sub=$(basename $(dirname $(dirname $(dirname $(dirname ${dtseries})))))
    task=$(echo $func_base | sed 's/_desc-preproc//g')

    if [[ "$dtseries" == *"ses"* ]]; then

        ses="$(cut -f1 -nd "_" <<< "$func_base")"
        ses_="${ses}_"

    else
        ses=""
        ses_=""

    fi

    confounds_tsv=fmriprep/${sub}/${ses}/func/${sub}_${ses_}${task}_desc-confounds_regressors.tsv
    cleaned_dtseries=cifti_clean/${sub}/${ses}/func/${sub}_${ses_}${task}_space-fsLR_den-91k_desc-cleaneds0_bold.dtseries.nii

    mkdir -p ${DERIVED_DIR}/cifti_clean/${sub}/${ses}/func/

    # run cifti clean step
    singularity exec \
    -H ${sing_home} \
    -B ${DERIVED_DIR}:/derived \
    -B ${CODEDIR}:/code \
    ${SING_CONTAINER} \
        ciftify_clean_img \
        --output-file=/derived/${cleaned_dtseries} \
        --clean-config=/code/${clean_config} \
        --left-surface=/derived/ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.midthickness.32k_fs_LR.surf.gii \
        --right-surface=/derived/ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.midthickness.32k_fs_LR.surf.gii \
        --confounds-tsv=/derived/${confounds_tsv} \
        /derived/ciftify/${sub}/MNINonLinear/Results/${func_base}/${func_base}_Atlas_s0.dtseries.nii

    # build a qc visualization for the cleaned images
    singularity exec \
    -H ${sing_home} \
    -B ${DERIVED_DIR}:/derived \
    -B ${CODEDIR}:/code \
    ${SING_CONTAINER} \
    cifti_vis_RSN cifti-subject \
    --qcdir /derived/cifti_clean/qc_rsn \
    --ciftify-work-dir /derived/ciftify \
    /derived/${cleaned_dtseries} \
    ${sub}



rm -r ${sing_home}

}

export -f run_cleaning_script

parallel -j ${SUB_SIZE} --tag --line-buffer --compress \
 "run_cleaning_script {1}" \
    ::: ${THESE_DTSERIES} 
