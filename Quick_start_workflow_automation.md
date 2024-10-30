# Automated Pipeline Coordination and Code Integration for Efficient Workflow Execution

In this project, we have devised a streamlined solution for managing multiple pipelines with a focus on seamless coordination and code integration. Our approach involves the creation of an automated system that orchestrates the execution of diverse pipelines each stage. By combining and organizing the necessary codes for each stage's tasks, we aim to optimize workflow efficiency.

After setting up the scinet environment and organizing your bids folder and participants.csv file, you can run the codes for each stage.

The script will prompt you at each stage to ask if you want to run only the functional pipelines. This allows you to skip the diffusion pipelines if you don't want to run them or if you don't have diffusion scans.

## stage 1 (mriqc, fmriprep_anat, qsiprep, freesurfer, smriprep):
```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_1.sh
```


## stage 2 (ciftify_anat, fmriprep_func, qsirecon1, amico_noddi,tractography, freesurfer_group):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_2.sh
```

## stage 3 (xcp_d, xcp_noGSR, qsirecon2):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_3.sh
```

## stage 4 (enigma dti):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_4.sh
```

## stage 5 (noddi_extract):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_5.sh
```

## stage 6 (extract data to share folder):

```sh
# note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_6.sh
```
