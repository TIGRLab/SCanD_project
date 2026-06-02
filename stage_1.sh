#!/bin/bash

#stage1 (mriqc, qsiprep, fmriprep_fit, freesurfer, smriprep, magetbrain_init):

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

# Prompt user for each pipeline
run_pipeline "mriqc" "./code/01_mriqc_scinet.sh" 1
run_pipeline "qsiprep" "./code/01_qsiprep_scinet.sh" 1
run_pipeline "fmriprep_fit" "./code/01_fmriprep_fit_scinet.sh" 1
run_pipeline "freesurfer" "./code/01_freesurfer_long_scinet.sh" 1
run_pipeline "smriprep" "./code/01_smriprep_scinet.sh" 1

# Prompt for magetbrain_init
read -p "Do you want to run the magetbrain_init pipeline? (yes/no): " run_magetbrain
if [[ "$run_magetbrain" =~ ^(yes|y)$ ]]; then
    echo "Running magetbrain_init..."
    sbatch ./code/01_magetbrain_init_scinet.sh
else
    echo "Skipping magetbrain_init."
fi
