#!/bin/bash

## stage 4 (parcellation_ciftify, enigma_dti)
# Ask the user whether to run only parcellation_ciftify
read -p "Do you want to only run functional codes? (yes/no): " RUN_PARCELLATION_ONLY

if [ "$RUN_PARCELLATION_ONLY" = "yes" ] || [ "$RUN_PARCELLATION_ONLY" = "y" ]; then
    echo "Running only parcellation_ciftify"

    ## Stage 4: parcellation_ciftify
    SUB_SIZE=10 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/04_parcellate_ciftify_scinet.sh

else
    echo "Running all codes: parcellation_ciftify and enigma_dti"

    ## Stage 4: enigma_dti
    sbatch ./code/04_enigma_dti_scinet.sh

    ## Stage 4: parcellation_ciftify
    SUB_SIZE=10 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/04_parcellate_ciftify_scinet.sh
fi

