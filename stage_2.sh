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
run_pipeline "ciftify_anat" "./code/02_ciftify_anat_scinet.sh" 1
run_pipeline "fmriprep_apply" "./code/02_fmriprep_apply_scinet.sh" 1
run_pipeline "freesurfer_group" "./code/02_freesurfer_group_scinet.sh" 1

# Prompt for magetbrain_register
read -p "Do you want to run the magetbrain_register pipeline? (yes/no): " run_magetbrain
if [[ "$run_magetbrain" =~ ^(yes|y)$ ]]; then
    echo "Running magetbrain_register..."
    sbatch ./code/02_magetbrain_register_scinet.sh
else
    echo "Skipping magetbrain_register."
fi
