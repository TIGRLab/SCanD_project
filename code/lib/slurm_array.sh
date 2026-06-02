#!/usr/bin/env bash
# Shared SLURM array sizing — matches the chunking logic in *_scinet.sh scripts.

# Echo the maximum array task index (0-based) for n subjects and chunk size sub_size.
scand_slurm_array_max() {
    local n_subjects=$1
    local sub_size=$2
    local array_job_length tail

    if [ "$n_subjects" -le 0 ] || [ "$sub_size" -le 0 ]; then
        echo "-1"
        return
    fi

    array_job_length=$(echo "$n_subjects / ${sub_size}" | bc)
    tail=$((n_subjects - (array_job_length * sub_size)))

    if [ "$tail" -eq 0 ]; then
        echo $((array_job_length - 1))
    else
        echo "$array_job_length"
    fi
}

# Submit a participant-array job. Remaining arguments after sub_size are passed to sbatch.
scand_submit_participant_array() {
    local script=$1
    local sub_size=$2
    local participants_tsv="./data/local/bids/participants.tsv"
    local n_subjects max_task

    shift 2

    n_subjects=$(( $( wc -l "${participants_tsv}" | cut -f1 -d' ' ) - 1 ))
    max_task=$(scand_slurm_array_max "$n_subjects" "$sub_size")

    if [ "$max_task" -lt 0 ]; then
        echo "No subjects in ${participants_tsv}; skipping ${script}"
        return 1
    fi

    echo "Submitting ${script} with array 0-${max_task} (${n_subjects} subjects, SUB_SIZE=${sub_size})"
    sbatch --array=0-"${max_task}" "$script" "$@"
}
