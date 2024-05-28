#!/bin/bash

## stage 3 (ciftify_anat, xcp-d, qsirecon_step2, tractography, enigma extract):
# Ask the user whether to run only xcp_d, ciftify_anat, and enigma_extract
read -p "Do you want to only functional codes? (yes/no): " RUN_SPECIFIC_ONLY

if [ "$RUN_SPECIFIC_ONLY" = "yes" ] || [ "$RUN_SPECIFIC_ONLY" = "y" ]; then
    echo "Running only xcp_d, ciftify_anat, and enigma_extract"

    ## Stage 3: ciftify_anat
    ## figuring out appropriate array-job size
    SUB_SIZE=8
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_ciftify_anat_scinet.sh

    ## Stage 3: xcp_d
    ## figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_xcp_scinet.sh

    ## Stage 3: enigma_extract
    source ./code/03_ENIGMA_ExtractCortical.sh

else
    echo "Running all codes: ciftify_anat, xcp_d, qsirecon_step2, tractography, and enigma_extract"

    ## Stage 3: ciftify_anat
    ## figuring out appropriate array-job size
    SUB_SIZE=8
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_ciftify_anat_scinet.sh

    ## Stage 3: xcp_d
    ## figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_xcp_scinet.sh

    ## Stage 3: qsirecon step2
    ## figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_qsirecon_step2_scinet.sh

    ## Stage 3: tractography
    ## figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/03_tractography_scinet.sh

    ## Stage 3: enigma_extract
    source ./code/03_ENIGMA_ExtractCortical.sh
fi
