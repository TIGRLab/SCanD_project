#!/bin/bash

## stage 3 (xcp-d, xcp_noGSR, magetbrain_vote, qsirecon_dtifit, noddireg, glm_surface):

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit 1
# shellcheck source=code/lib/slurm_array.sh
source "${SCRIPT_DIR}/code/lib/slurm_array.sh"

submit_array_job() {
    scand_submit_participant_array "$@"
}

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

submit_magetbrain_job() {
    local sub_size=1
    local subjects_list=($(ls ./data/local/derivatives/MAGeTbrain/magetbrain_data/input/subjects/brains/*.mnc | xargs -n 1 basename | sed 's/\.mnc$//'))
    local n_subjects=${#subjects_list[@]}
    local max_task

    max_task=$(scand_slurm_array_max "$n_subjects" "$sub_size")
    if [ "$max_task" -lt 0 ]; then
        echo "No MAGeTbrain .mnc files found; skipping MAGeTbrain_vote."
        return 1
    fi

    echo "Submitting MAGeTbrain Vote job with array 0-${max_task} (${n_subjects} subjects)"
    sbatch --array=0-"${max_task}" ./code/03_magetbrain_vote_scinet.sh
}

# Prompt user for each pipeline
run_pipeline "xcp-d" "./code/03_xcp_scinet.sh" 1
run_pipeline "xcp-noGSR" "./code/03_xcp_noGSR_scinet.sh" 1
run_pipeline "qsirecon_dtifit" "./code/03_qsirecon_dtifit_scinet.sh" 1
run_pipeline "noddi-registration" "./code/03_noddi_reg_scinet.sh" 1

read -p "Do you want to run the glm_surface pipeline? (yes/no): " run_glm
if [[ "$run_glm" =~ ^(yes|y)$ ]]; then
    echo "Provide the path to your study-specific BIDS Stats Model JSON."
    echo "Example: code/glm/examples/models/<STUDY_NAME>/model-001_smdl.json"
    read -p "Model path: " MODEL
    # Expand ~ and allow relative paths from the project root
    MODEL="${MODEL/#\~/$HOME}"
    if [[ "$MODEL" != /* ]]; then
        MODEL="${SCRIPT_DIR}/${MODEL}"
    fi
    if [ ! -f "$MODEL" ]; then
        echo "ERROR: MODEL file not found at $MODEL"
        exit 1
    fi
    echo "Running glm_surface with model: $MODEL"
    scand_submit_participant_array "./code/03_glm_surface_scinet.sh" 1 "$MODEL"
else
    echo "Skipping glm_surface."
fi

read -p "Do you want to run the MAGeTbrain_vote pipeline? (yes/no): " run_magetbrain
if [[ "$run_magetbrain" =~ ^(yes|y)$ ]]; then
    submit_magetbrain_job
else
    echo "Skipping MAGeTbrain_vote."
fi
