# Automated Pipeline Coordination and Code Integration for Efficient Workflow Execution

In this project, we have devised a streamlined solution for managing multiple pipelines with a focus on seamless coordination and code integration. Our approach involves the creation of an automated system that orchestrates the execution of diverse pipelines each stage. By combining and organizing the necessary codes for each stage's tasks, we aim to optimize workflow efficiency.

After setting up the scinet environment and organizing your bids folder and participants.csv file, you can run the codes for each stage.

## stage 1 (mriqc, fmriprep_anat, qsiprep):
```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_1.sh
```


## stage 2 (fmriprep_func, qsirecon1):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_2.sh
```

## stage 3 (ciftify_anat, xcp_scinet, tractography, enigma extract, enigma_dti, qsirecon2):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_3.sh
```

## stage 4 (parcellation_ciftify):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_4.sh
```
## stage 5 (extract data to share folder):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_5.sh
```
