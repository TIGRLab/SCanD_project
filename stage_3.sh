#!/bin/bash

## stage 3 (ciftify_anat, xcp-d, qsirecon_step2):
# Ask the user whether to run only xcp_d and ciftify_anat
read -p "Do you want to only run functional pipelines? (yes/no): " RUN_SPECIFIC_ONLY

if [ "$RUN_SPECIFIC_ONLY" = "yes" ] || [ "$RUN_SPECIFIC_ONLY" = "y" ]; then
    echo "Running only xcp_d and ciftify_anat"

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


else
    
    echo "Running all codes: ciftify_anat, xcp_d and qsirecon_step2"

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

fi
