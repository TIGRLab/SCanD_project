#!/bin/bash

## stage 3 (ciftify_anat, xcp-d, qsirecon_step2, tractography, enigma extract):
# Ask the user whether to run only xcp_d, ciftify_anat, and enigma_extract
read -p "Do you want to only run functional pipelines? (yes/no): " RUN_SPECIFIC_ONLY

if [ "$RUN_SPECIFIC_ONLY" = "yes" ] || [ "$RUN_SPECIFIC_ONLY" = "y" ]; then
    echo "Running only xcp_d, ciftify_anat, and enigma_extract"

    ## Stage 3: ciftify_anat
    ## Figuring out appropriate array-job size
    SUB_SIZE=8
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    ## Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_ciftify_anat_scinet.sh

    ## Stage 3: xcp_d
    ## Figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    ## Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_xcp_scinet.sh

    ## Stage 3: enigma_extract
    source ./code/03_ENIGMA_ExtractCortical.sh

else
    # Ask the user whether the data is single-shell or multi-shell
    read -p "Is the data single-shell or multi-shell? (single/multi): " DATA_SHELL_TYPE

    if [ "$DATA_SHELL_TYPE" != "single" ] && [ "$DATA_SHELL_TYPE" != "multi" ]; then
        echo "Invalid input. Please specify either 'single' or 'multi' for the data shell type."
        exit 1
    fi

    echo "Running all codes: ciftify_anat, xcp_d, qsirecon_step2, tractography, and enigma_extract"

    ## Stage 3: ciftify_anat
    ## Figuring out appropriate array-job size
    SUB_SIZE=8
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    ## Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_ciftify_anat_scinet.sh

    ## Stage 3: xcp_d
    ## Figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    ## Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_xcp_scinet.sh

    ## Stage 3: qsirecon step2
    ## Figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    ## Submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_qsirecon_step2_scinet.sh

    ## Stage 3: tractography
    ## Figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $(wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ') - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "Number of array is: ${array_job_length}"

    if [ "$DATA_SHELL_TYPE" = "multi" ]; then
        # Submit the array job to the queue for multi-shell data
        sbatch --array=0-${array_job_length} ./code/03_tractography_multi_scinet.sh
    else
        # Submit the array job to the queue for single-shell data
        sbatch --array=0-${array_job_length} ./code/03_tractography_single_scinet.sh
    fi

    ## Stage 3: enigma_extract
    source ./code/03_ENIGMA_ExtractCortical.sh
fi
