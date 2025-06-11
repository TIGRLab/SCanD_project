#!/bin/bash

# Stage 2 (qsiprep, ciftify_anat, fmriprep_apply, freesurfer_group, magetbrain_register):

#!/bin/bash

# Function to calculate and submit array jobs
submit_array_job() {
    local script=$1
    local sub_size=$2
    local n_subjects=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    local array_job_length=$(( n_subjects / sub_size ))
    echo "Submitting job for $script with array size: ${array_job_length}"
    sbatch --array=0-${array_job_length} $script
}

# Function to prompt user and run selected pipeline
run_pipeline() {
    local pipeline_name=$1
    local script_path=$2
    local sub_size=$3
    read -p "Do you want to run the $pipeline_name pipeline? (yes/no): " run_pipeline
    
    if [[ "$run_pipeline" =~ ^(yes|y)$ ]]; then
        echo "Running $pipeline_name..."
        submit_array_job $script_path $sub_size
    else
        echo "Skipping $pipeline_name."
    fi
}


# Prompt user for each pipeline in stage 2
run_pipeline "qsiprep" "./code/02_qsiprep_scinet.sh" 1
run_pipeline "fmriprep_apply" "./code/02_fmriprep_apply_scinet.sh" 1
run_pipeline "freesurfer_group" "./code/02_freesurfer_group_scinet.sh" 1


# Prompt separately for ciftify_anat (uses long folder names, not participants.tsv)
read -p "Do you want to run the ciftify_anat pipeline? (yes/no): " run_ciftify
if [[ "$run_ciftify" =~ ^(yes|y)$ ]]; then
    echo "Running ciftify_anat..."

    SUBJECTS_DIR="./data/local/derivatives/freesurfer/7.4.1"
    N_SUBJECTS=$(ls -d ${SUBJECTS_DIR}/*long* 2>/dev/null | wc -l)

    if [[ "$N_SUBJECTS" -eq 0 ]]; then
        echo "No *long* subject folders found in ${SUBJECTS_DIR}. Skipping ciftify_anat."
    else
        ARRAY_JOB_LENGTH=$((N_SUBJECTS - 1))
        echo "Submitting ciftify_anat job array with indices 0 to ${ARRAY_JOB_LENGTH}"
        sbatch --array=0-${ARRAY_JOB_LENGTH} ./code/02_ciftify_anat_scinet.sh
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
