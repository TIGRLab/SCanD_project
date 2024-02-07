# Automated Daily Pipeline Coordination and Code Integration for Efficient Workflow Execution

In this project, we have devised a streamlined solution for managing multiple daily pipelines with a focus on seamless coordination and code integration. Our approach involves the creation of an automated system that orchestrates the execution of diverse pipelines each stage. By combining and organizing the necessary codes for each stage's tasks, we aim to optimize workflow efficiency.

After setting up the scinet environment and organizing your bids folder and participants.csv file, you can run the codes for each stage.

## stage 1 (mriqc, fmriprep_anat, qsiprep):
```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull         #in case you need to pull new code


##mriqc
## calculate the length of the array-job given
SUB_SIZE=10
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/01_mriqc.sh


##fmriprep_anat
## figuring out appropriate array-job size
SUB_SIZE=1
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} code/01_fmriprep_anat_scinet.sh


#qsiprep
## figuring out appropriate array-job size
SUB_SIZE=2 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/01_qsiprep_scinet.sh
```


## stage 2 (fmriprep_func, enigma_dti):

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

##fmriprep_func
## figuring out appropriate array-job size
SUB_SIZE=2 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_fmriprep_func_scinet.sh

##enigma_dti
## figuring out appropriate array-job size
SUB_SIZE=2 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_enigma_dti_scinet.sh
```

## stage 3 (ciftify_anat, xcp_scinet, enigma extract):

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

##ciftify_anat
## figuring out appropriate array-job size
SUB_SIZE=8 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/03_ciftify_anat_scinet.sh

##xcp_d
## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/03_xcp_scinet.sh

##enigma_extract
source ./code/03_ENIGMA_ExtractCortical.sh
```

## stage 4 (parcellation):

```sh

## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

SUB_SIZE=10 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_DTSERIES=$(ls -1d ./data/local/ciftify/sub*/MNINonLinear/Results/*task*/*dtseries.nii | wc -l)
array_job_length=$(echo "$N_DTSERIES/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/04_parcellate_scinet.sh
```
## stage 5 (extract data to share folder):

```sh
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

source ./code/04_extract_to_share.sh

```
