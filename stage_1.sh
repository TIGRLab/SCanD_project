#!/bin/bash

#stage1 (mriqc, fmriprep_fit, freesurfer, qsiprep):
# Ask the user whether to run only functional codes
read -p "Do you want to only run functional pipelines? (yes/no): " RUN_FUNCTIONAL_ONLY

if [ "$RUN_FUNCTIONAL_ONLY" = "yes" ] || [ "$RUN_FUNCTIONAL_ONLY" = "y" ]; then
    # Run only mriqc and fmriprep_anat
    echo "Running only functional codes: mriqc and fmriprep_anat"

    ## mriqc
    ## calculate the length of the array-job given
    SUB_SIZE=4
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/01_mriqc_scinet.sh

    ## fmriprep_fit
    ## figuring out appropriate array-job size

    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} code/01_fmriprep_fit_scinet.sh


    ## submitting freesurfer longitudinal
    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} code/01_freesurfer_long_scinet.sh
else
    # Run all three codes: mriqc, fmriprep_anat, and qsiprep
    echo "Running all codes: mriqc, fmriprep_anat, and qsiprep"

    ## mriqc
    ## calculate the length of the array-job given
    SUB_SIZE=4
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/01_mriqc_scinet.sh

    ## fmriprep_fit
    ## figuring out appropriate array-job size
    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} code/01_fmriprep_fit_scinet.sh

    ## submitting freesurfer longitudinal
    SUB_SIZE=1
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} code/01_freesurfer_long_scinet.sh

    ## qsiprep
    ## figuring out appropriate array-job size
    SUB_SIZE=2 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
    N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
    array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
    echo "number of array is: ${array_job_length}"

    ## submit the array job to the queue
    sbatch --array=0-${array_job_length} ./code/01_qsiprep_scinet.sh
fi
