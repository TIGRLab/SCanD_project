#!/bin/bash

# Stage 2 (ciftify_anat, fmriprep_apply, qsirecon_step1, amico_noddi, tractography, freesurfer_group):

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
run_pipeline "ciftify_anat" "./code/02_ciftify_anat_scinet.sh" 1
run_pipeline "fmriprep_apply" "./code/02_fmriprep_apply_scinet.sh" 1
run_pipeline "qsirecon_step1" "./code/02_qsirecon_step1_scinet.sh" 1
run_pipeline "amico_noddi" "./code/02_amico_noddi.sh" 1
run_pipeline "freesurfer_group" "./code/02_freesurfer_group_scinet.sh" 1
run_pipeline "tractography_multi shell" "./code/02_tractography_multi_scinet.sh" 1
run_pipeline "tractography_single shell" "./code/02_tractography_single_scinet.sh" 1
