#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=80
#SBATCH --time=00:30:00
#SBATCH --export=ALL
#SBATCH --job-name="xcp_parcellate"
#SBATCH --output=logs/xcp_parcellate_%j.out

## set the second environment variable to get the base directory
BASEDIR=${SLURM_SUBMIT_DIR}

## this script requires gnu-parallel
module load gnu-parallel/20191122

## note the dlabel file path must be a relative to the output folder
export parcellation_dir=${BASEDIR}/data/local/xcp_d
export atlases=("Tian" "HCP")  # Define the atlases here

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

# find all dtseries inputs for this study - by globbing the ciftify outputs
xcp_folder=${DERIVED_DIR}/xcp_d
ALL_DTSERIES=$(ls -1d ${xcp_folder}/sub*/ses*/func/*dtseries*)

## get the subject list from a combo of the array id, the participants.tsv and the chunk size
SUB_SIZE=10 ## number of subjects to run
bigger_bit=$(echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc)

# select the dtseries to run in this chunk
THESE_DTSERIES=$(for dt in ${ALL_DTSERIES}; do echo $dt; done | head -n ${bigger_bit} | tail -n ${SUB_SIZE})

run_parcellation() {
    atlas=$1
    dtseries=${2}

    sing_home=$(mktemp -d -t wb-XXXXXXXXXX)

    # determine the output filenames based on the input filename
    func_base=$(basename $(dirname ${dtseries}))
    sub=$(basename $(dirname $(dirname $(dirname ${dtseries}))))
    ses=$(basename $(dirname $(dirname ${dtseries})))
    ses_="${ses}_"

    task=$(echo "$dtseries" | sed 's/.*task-\([^_/]*\).*_run-\([^_/]*\).*/task-\1_run-\2/')

    cleaned_dtseries=xcp_d/${sub}/${ses}/func/${sub}_${ses_}${task}_space-fsLR_den-91k_desc-denoised_bold.dtseries.nii
    output_ptseries=parcellated/${atlas}/ptseries/${sub}/${ses}/func/${sub}_${ses_}${task}_${atlas}_desc-cleaneds0_bold.ptseries.nii
    output_csv=parcellated/${atlas}/csv/${sub}/${ses}/func/${sub}_${ses_}${task}_${atlas}_desc-cleaneds0_meants.csv

    mkdir -p ${DERIVED_DIR}/parcellated/${atlas}/ptseries/${sub}/${ses}/func
    mkdir -p ${DERIVED_DIR}/parcellated/${atlas}/csv/${sub}/${ses}/func
    
    echo "Running parcellation on ${cleaned_dtseries}"

    # Set dlabel_file according to the current atlas
    if [ "$atlas" == "Tian" ]; then
        export dlabel_file="space-fsLR_atlas-Tian_den-91k_dseg.dlabel.nii"
    elif [ "$atlas" == "HCP" ]; then
        export dlabel_file="space-fsLR_atlas-HCP_den-91k_dseg.dlabel.nii"
    fi

    # parcellate to a ptseries file
    singularity exec \
    -H ${sing_home} \
    -B ${DERIVED_DIR}:/output \
    -B ${parcellation_dir}:/parcellations \
    ${SING_CONTAINER} \
    wb_command -cifti-parcellate \
    /output/${cleaned_dtseries} \
    /parcellations/${dlabel_file} \
    COLUMN \
    /output/${output_ptseries} \
    -include-empty

    # convert the ptseries to a csv
    singularity exec \
    -H ${sing_home} \
    -B ${DERIVED_DIR}:/output \
    ${SING_CONTAINER} wb_command -cifti-convert -to-text \
    /output/${output_ptseries} \
    /output/${output_csv} \
    -col-delim ","

    rm -r ${sing_home}
}

export -f run_parcellation

# Loop over the atlases
for atlas in "${atlases[@]}"; do
    parallel -j ${SUB_SIZE} --tag --line-buffer --compress "run_parcellation ${atlas} {1}" ::: ${THESE_DTSERIES}
done
