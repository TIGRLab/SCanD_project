#!/bin/bash

## stage 5 (noddi_extract)

# Function to calculate and submit array jobs
submit_array_job() {
    local script=$1
    echo "Submitting job for $script"
    sbatch $script
}

# Function to prompt user and run selected pipeline
run_pipeline() {
    local pipeline_name=$1
    local script_path=$2
    read -p "Do you want to run the $pipeline_name pipeline? (yes/no): " run_pipeline
    if [[ "$run_pipeline" =~ ^(yes|y)$ ]]; then
        echo "Running $pipeline_name..."
        submit_array_job $script_path
    else
        echo "Skipping $pipeline_name."
    fi
}

# Prompt user for each pipeline in stage 5
run_pipeline "noddi_extract" "./code/05_extract_noddi_scinet.sh"
