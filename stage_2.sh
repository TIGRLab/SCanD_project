#!/bin/bash

# Stage 2 (fmriprep_func, qsirecon_step1, amico_noddi):

# Ask the user whether to run only fmriprep_func
read -p "Do you want to only run functional pipelines? (yes/no): " RUN_FMRIPREP_FUNC_ONLY

if [ "$RUN_FMRIPREP_FUNC_ONLY" = "yes" ] || [ "$RUN_FMRIPREP_FUNC_ONLY" = "y" ]; then
    echo "Running only fmriprep_func"

    # Stage 2: fmriprep_func
    # Figuring out appropriate array-job size
    SUB_SIZE=1 # For func the sub size is moving to 1 participant because there are two runs and 8 tasks per run
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    # Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/02_fmriprep_func_scinet.sh

else

    # Ask the user whether the data is single-shell or multi-shell
    read -p "Is the data single-shell or multi-shell? (single/multi): " DATA_SHELL_TYPE

    # Stage 2: fmriprep_func
    # Figuring out appropriate array-job size
    SUB_SIZE=1 # For func the sub size is moving to 1 participant because there are two runs and 8 tasks per run
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    # Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/02_fmriprep_func_scinet.sh

    # Stage 2: qsirecon step1
    # Figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    # Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/02_qsirecon_step1_scinet.sh

    if [ "$DATA_SHELL_TYPE" = "multi" ]; then
       echo "Running all codes: fmriprep_func, qsirecon_step1, and possibly amico_noddi"
       
        # Stage 2: amico_noddi (only for multi-shell data)
        # Figuring out appropriate array-job size
        SUB_SIZE=1
        N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
        array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
        echo "Number of array is: ${array_job_length}"

        # Submit the array job to the queue
        sbatch --array=0-${array_job_length} ./code/02_amico_noddi.sh
    else
        echo "Skipping amico_noddi as the data is single-shell."
    fi
fi
