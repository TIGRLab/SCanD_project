#!/bin/bash

## stage 3 (ciftify_anat, xcp-d, qsirecon_step2):

submit_array_job() {
    local script=$1
    local sub_size=$2
    local n_subjects=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
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

# Prompt user for each pipeline
run_pipeline "ciftify_anat" "./code/03_ciftify_anat_scinet.sh" 8
run_pipeline "xcp-d" "code/03_xcp_scinet.sh" 1
run_pipeline "qsirecon_step2" "code/03_qsirecon_step2_scinet.sh" 1
