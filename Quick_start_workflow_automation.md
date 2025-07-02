# Automated Pipeline Coordination and Code Integration for Efficient Workflow Execution

In this project, we have devised a streamlined solution for managing multiple pipelines with a focus on seamless coordination and code integration. Our approach involves the creation of an automated system that orchestrates the execution of diverse pipelines each stage. By combining and organizing the necessary codes for each stage's tasks, we aim to optimize workflow efficiency.

The script will prompt you at each stage to ask if you want to run only the functional pipelines. This allows you to skip the diffusion pipelines if you don't want to run them or if you don't have diffusion scans.

**Note:** At any stage, before proceeding to the next stage and executing the codes for the subsequent phase, it's crucial to navigate to the Neurobagel/derivatives/processing_status.tsv and review the file for all pipelines from the previous stage. For instance, if you intend to execute stage 3 code, you must examine the processing_status.tsv for all the pipelins in stage 2. If no participants have encountered failures, you may proceed with running the next stage. You can also upload your file to [Neurobagel Digest](https://digest.neurobagel.org/) to gain more insight into the status of your pipelines and to filter them for easier review. If any participant has failed, you need to first amend the data/local/bids/participants.tsv file by including the IDs of the failed participants. After rectifying the errors, rerun the pipeline with the updated participant list.

## stage 0 (setup bids folder and SciNet environment)

After setting up the SciNet environment and organizing your BIDS folder and participants.csv file, you can run the codes for each stage.

## stage 1 (mriqc, fmriprep_fit, freesurfer, smriprep, magetbrain_init):
```sh
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_1.sh
```


## stage 2 (qsiprep, ciftify_anat, fmriprep_apply, freesurfer_group, magetbrain_register):

```sh
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_2.sh
```

## stage 3 (xcp_d, xcp_noGSR, magetbrain_vote, qsirecon1, amico_noddi, tractography):

```sh
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_3.sh
```

## stage 4 (qsirecon2):

```sh
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_4.sh
```

## stage 5 (enigma_dti):

```sh
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_5.sh
```

## stage 6 (noddi_extract):

```sh
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_6.sh
```

## stage 7 (extract data to share folder):

```sh
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

source ./stage_7.sh
```


After you are done with stage 7, verify your data/share folder using [share_folder.md](https://github.com/TIGRLab/SCanD_project/blob/Cedar/share_folder.md). Ensure all folders and files match the checklist. Once confirmed, copy your folder into the shared space.

You need to change the "your_group_name" and put your group name there and then run the code!

```sh
cd ${SCRATCH}/SCanD_project

mkdir /scratch/arisvoin/shared/your_group_name
cp -r data/share  /scratch/arisvoin/shared/your_group_name/
```
