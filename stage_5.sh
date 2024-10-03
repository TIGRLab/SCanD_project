#!/bin/bash

## stage 5 (noddi_extract)
#!/bin/bash

# Function to calculate and submit array jobs
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
        if [ "$sub_size" -eq 1 ]; then
            sbatch $script_path
        else
            submit_array_job $script_path $sub_size
        fi
    else
        echo "Skipping $pipeline_name."
    fi
}

# Prompt user for each pipeline in stage 4
run_pipeline "noddi_extract" "./code/05_extract_noddi_scinet.sh" 1
