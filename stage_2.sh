#!/bin/bash

# Stage 2 (ciftify_anat, fmriprep_apply, freesurfer_parcellate, magetbrain_register, qsirecon_FSL, amico_noddi, tractography):

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit 1
# shellcheck source=code/lib/slurm_array.sh
source "${SCRIPT_DIR}/code/lib/slurm_array.sh"

submit_array_job() {
    scand_submit_participant_array "$1" "$2"
}

# Function to prompt user and run selected pipeline
run_pipeline() {
    local pipeline_name=$1
    local script_path=$2
    local sub_size=$3
    read -p "Do you want to run the $pipeline_name pipeline? (yes/no): " run_pipeline
    
    if [[ "$run_pipeline" =~ ^(yes|y)$ ]]; then
        echo "Running $pipeline_name..."
        submit_array_job "$script_path" "$sub_size"
    else
        echo "Skipping $pipeline_name."
    fi
}


# Prompt user for each pipeline in stage 2
run_pipeline "fmriprep_apply" "./code/02_fmriprep_apply_scinet.sh" 1
run_pipeline "freesurfer_parcellate" "./code/02_freesurfer_atlas_parcellate_scinet.sh" 1
run_pipeline "qsirecon_FSL" "./code/02_qsirecon_FSL_scinet.sh" 1
run_pipeline "amico_noddi" "./code/02_amico_noddi_scinet.sh" 1
run_pipeline "tractography_multi shell" "./code/02_tractography_multi_scinet.sh" 1
run_pipeline "tractography_single shell" "./code/02_tractography_single_scinet.sh" 1


# Prompt separately for ciftify_anat (uses long folder names, not participants.tsv)
read -p "Do you want to run the ciftify_anat pipeline? (yes/no): " run_ciftify
if [[ "$run_ciftify" =~ ^(yes|y)$ ]]; then
    echo "Running ciftify_anat..."

    SUBJECTS_DIR="./data/local/derivatives/freesurfer/7.4.1"

    if compgen -G "${SUBJECTS_DIR}/*long*" > /dev/null; then
      SUBJECT_FOLDERS=(${SUBJECTS_DIR}/*long*)
    else
      SUBJECT_FOLDERS=(${SUBJECTS_DIR}/*sub-*)
    fi

    N_SUBJECTS=${#SUBJECT_FOLDERS[@]}

    if [[ "$N_SUBJECTS" -eq 0 ]]; then
        echo "No subject folders found in ${SUBJECTS_DIR}. Skipping ciftify_anat."
    else
        max_task=$(scand_slurm_array_max "$N_SUBJECTS" 1)
        echo "Submitting ciftify_anat job array with indices 0 to ${max_task}"
        sbatch --array=0-${max_task} ./code/02_ciftify_anat_scinet.sh
    fi
else
    echo "Skipping ciftify_anat."
fi


# Prompt for magetbrain_register
read -p "Do you want to run the magetbrain_register pipeline? (yes/no): " run_magetbrain
if [[ "$run_magetbrain" =~ ^(yes|y)$ ]]; then
    echo "Running magetbrain_register..."
    sbatch ./code/02_magetbrain_register_scinet.sh
else
    echo "Skipping magetbrain_register."
fi
