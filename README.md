# SCanD_project

This is a base repo for the Schizophrenia Canadian Neuroimaging Database (SCanD) codebase. It is meant to be forked/cloned for every SCanD dataset.

General folder structure for the repo (when all is run)

```
${BASEDIR}
├── code                         # a clone of this repo
│   └── ...    
├── containers                   # the singularity image are copied or linked to here
│   ├── fmriprep-20.2.7.simg 
│   ├── mriqc-22.0.6.simg simg
│   ├── qsiprep_0.16.0RC3.simg
│   ├── freesurfer-6.0.1.simg
│   ├── fmriprep_ciftity-v1.3.2-2.3.3.simg
│   ├── tbss_2023-10-10.simg
│   ├── pennbbl_qsiprep_0.14.3-2021-09-16-e97e6c169493.simg
│   └── xcp_d-0.6.0.simg
├── data
│   ├── local                    # folder for the "local" dataset
│   │   ├── bids                 # the defaced BIDS dataset
│   │   ├── amico_noddi          # amico_noddi derivatives
│   │   ├── mriqc                # mriqc derivatives
│   │   ├── fmriprep             # fmriprep derivatives
│   │   ├── freesurfer           # freesurfer derivative - generated during fmriprep
│   │   ├── freesurfer_long      # freesurfer longitudinal
│   │   ├── qsiprep              # full qsiprep derivatives
│   │   ├── ciftify              # ciftify derivatives
│   │   ├── ENIGMA_extract       # extracted cortical and subcortical csv files
│   │   ├── dtifit               #dtifit
│   │   ├── enigmaDTI            #enigmadti
│   │   ├── qsirecon             #qsirecon derivatives
│   │   ├── xcp_d                #xcp with GSR
│   │   └── xcp_noGSR            #xcp with GSR removed
│   |
│   └── share                    # folder with a smaller subset ready to share
│       ├── amico                # contains only qc images and metadata
│       ├── mriqc                # contains only qc images and metadata
│       ├── fmriprep             # contains only qc images and metadata
│       ├── qsiprep              # contains only qc images and metadata
│       ├── ciftify              # contains only qc images and metadata
│       ├── ENIGMA_extract       # extracted cortical and subcortical csv files
│       ├── enigmaDTI            # enigmaDTI
│       ├── tractify             # contains connectivity.mat file
│       ├── xcp-d                # contains xcp results with GSR
│       └── xcp_noGSR            # contains xcp results with GSR removed
├── logs                         # logs from jobs run on cluster                 
|── README.md
|── LICENSE
|── share folder.md
|──stage_1.sh
|──stage_2.sh
|──stage_3.sh
|──stage_4.sh
|──stage_5.sh
|──stage_6.sh
|── Quick start_workflow automation.md
|── QC guide.md
└── templates                  # an extra folder with pre-downloaded fmriprep templates (see setup section)
    └── parcellations
        ├── README.md
        |── tpl-fsLR_res-91k_atlas-Glasser_dseg.dlabel.nii
        └── ...  #and 13 other atlases
```

Currently this repo is going to be set up for running things on SciNet Niagara cluster - but we can adapt later to create local set-ups behind hospital firewalls if needed.

# The general overview of what to do



| stage |  #	| Step	|   How Long Does it take to run? 	|
|---    |---	|---	|---	|
| stage 0|   0a	|  [Organize your data into BIDS..](#organize-your-data-into-bids) 	|   As long as it takes	|
|^ |   0b	|  [Deface the BIDS data (if not done during step 1)](#deface-the-bids-data-if-not-done-during-step-1) 	|   	|
|^ |   0c	|   [Setting up the SciNet environment](#Setting-your-scinet-enviromentcodeand-data)	| 30 minutes in terminal 	|
|^ |   0d	|   [Move you bids data to the correct place and add lables to participants.tsv file](#Put-your-bids-data-into-the-datalocal-folder-and-add-lables-to-participantstsv-file)	| depends on time to transfer data to SciNet  	|
|^ |   0e	|   [Edit fmap files](#Edit-fmap-files)	| 2 minutes in terminal 	|
|^ |   0f	|   [Final step before running the pipeline](#Final-step-before-running-the-pipeline)	| a few days to get buffer space 	|
|stage 1|   01a	|  [Run MRIQC](#Running-mriqc) 	|  18 hours on slurm 	|
|^|   01b	|  [Run freesurfer](#Running-freesurfer) 	|   16 hours on slurm	|
|^|   01c   |  [Run fMRIprep anat](#Running-fmriprep-anatomical-includes-freesurfer) 	|   16 hours on slurm	|
|^|   01d  |  [Run QSIprep](#Running-qsiprep) 	|   6 hours on slurm	|
|stage 2|   02a	|  [Run fMRIprep func](#Submitting-the-fmriprep-func-step) 	|  23 hours of slurm 	|
|^ |   02b	|  [Run qsirecon step1](#Running-qsirecon-step1) 	|  20 min of slurm 	|
|^ |   02c	|  [Run amico noddi](#Running-amico-noddi) 	| 6 hours of slurm 	|
|^ |   02d	|  [Run tractography](#Running-tractography) 	|  12 hour of slurm 	|
|^ |   02e	|  [Run freesurfer group analysis](#Running-freesurfer-group-analysis) 	|  3 hour of slurm 	|
|^ |   02f	|  [Run ciftify-anat](#Running-ciftify-anat) 	|  3 hours on slurm 	|
|stage 3 |   03a	|  [Run xcp-d](#Running-xcp-d) 	|  10 hours on slurm  |
|^ |   03b  |  [Run xcp no GSR](#Running-xcp-noGSR) 	|  10 hours on slurm  |
|^ |   03c	|  [Run qsirecon step2](#Running-qsirecon-step2) 	|  1 hour of slurm 	|
|stage 4 |   04a	|  [Run enigma-dti](#Running-enigma-dti) 	|  1 hours on slurm	|
|stage 5 |   05a	|  [Run extract_noddi](#Running-extract-noddi) 	|  3 hours on slurm	|
|^ |   05b	|  [Check tsv files](#Check-tsv-files) 	|    	|
|stage 6 |   06a	|  [Run extract and share to move to data to sharable folder](#Syncing-the-data-with-to-the-share-directory) 	|   30 min in terminal	|

## Organize your data into BIDS

This is the longest - most human intensive - step. But it will make everything else possible! BIDS is really a naming convention for your MRI data that will make it easier for other people the consortium (as well as the software) to understand what your data is (what scan types, how many participants, how many sessions..ect). Converting to BIDS may require renaming and/or reorganizing your current data. No coding is required, but there now a lot of different software projects out there to help out with the process.

For amazing tools and tutorials for learning how to BIDS convert your data, check out the [BIDS starter kit](https://bids-standard.github.io/bids-starter-kit/).


## Deface the BIDS data (if not done during step 1)

A useful tool is [this BIDSonym BIDS app](https://peerherholz.github.io/BIDSonym/).

## Setting your SciNet enviroment/code/and data

### Cloning this Repo

```sh
cd $SCRATCH
git clone https://github.com/TIGRLab/SCanD_project.git
```

## Run the software set-up script

```sh
cd ${SCRATCH}/SCanD_project
source code/00_setup_data_directories.sh
```

### Put your bids data into the data/local folder and add lables to participants.tsv file

We want to put your data into:

```
./data/local/bids
```
After organizing the bids folder, proceed to populate the participant labels, such as 'sub-CMH0047' within the 'ScanD_project/data/local/bids/participants.tsv' file.

#### For a test run of the code

For a test run of this available code you can work with a test dataset from open neuro - [check out the appendix for add the code to download test data](#appendix---adding-a-test-dataset-from-openneuro) . 

#### Your own data - continue from here

You can do this by either copying "scp -r", linking `ln -s` or moving the data to this place - it's your choice.

To copy the data from another computer/server you should be on the datamover node:


```sh
ssh <cc_username>@niagara.scinet.utoronto.ca
ssh nia-dm1
rsync -av <local_server>@<local_server_address>:/<local>/<server>/<path>/<bids> ${SCRATCH}/SCanD_project/data/local/
```

To link existing data from another location on SciNet Niagara to this folder:

```sh
ln -s /your/data/on/scinet/bids ${SCRATCH}/SCanD_project/data/local/bids
```
## Edit fmap files

In some cases dcm2niix conversion fails to add "IntendedFor" in the fmap files which causes errors in fmriprep_func step. Therefore, we need to edit fmap file in the bids folder and add "intendedFor"s. In order to edit these file we need to run a python code.

```sh
## First load a python module
module load NiaEnv/2019b python/3.11.5

## Create a directory for virtual environments if it doesn't exist
mkdir ~/.virtualenvs
cd ~/.virtualenvs
virtualenv --system-site-packages ~/.virtualenvs/myenv

## Activate the virtual environment
source ~/.virtualenvs/myenv/bin/activate 

python3 -m pip install bids

cd $SCRATCH/SCanD_project

python3 code/fmap_intended_for.py
```

In case you want to backup your json files before editting them:

```sh
mkdir bidsbackup_json
rsync -zarv  --include "*/" --include="*.json" --exclude="*"  data/local/bids  bidsbackup_json
```
## Final step before running the pipeline

The working directory for pipelines is based on the $BBUFFER environment variable, which assumes access to the buffer space. This setup significantly enhances code execution speed and overall performance.

To request access: If you do not already have access to the buffer folder, it is recommended to reach out to the SCINET group at support@scinet.utoronto.ca to request access.

Here is a sample email you can use:

* Subject: Request for BBUFFER Space for Preprocessing on SciNet Cluster
```
Hello,
I'm [your name] working at [site name] as a [your role] and I would like to request bbuffer space to do some preprocessing on the SciNet cluster. Specifically, I would like to run preprocessing scripts that use third party software that utilize high I/O for both logging and temporary files, and we're running them on large datasets so it would be ideal to run them as efficiently as possible. My account is [your scinet ID].
Let us know if you can get me access, any help would be greatly appreciated!
```
If BBUFFER space is unavailable or you choose not to use it, you need to navigate through each pipeline code and replace all instances of $BBUFFER with $SCRATCH/SCanD_project/work.

## Quick Start - Workflow Automation

After setting up the scinet environment and organizing your BIDS folder and `participants.csv` file, instead of running each pipeline separately, you can run the codes for each stage simultaneously. For a streamlined approach to running pipelines by stages, please refer to the [Quick start workflow automation.md](Quick_start_workflow_automation.md) document and proceed accordingly. Otherwise, run pipelines separately.

* Note: if you are running xcp-d pipeline (stage 3) for the first time, just make sure to run the codes to download the templateflow files before running the automated codes. You can find these codes below in [xcp-d](#Running-xcp-d) section.

## Running mriqc

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

## calculate the length of the array-job given
SUB_SIZE=4
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"


## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/01_mriqc_scinet.sh
```

## Running freesurfer

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

## calculate the length of the array-job given
SUB_SIZE=1
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"


## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/01_freesurfer_long_scinet.sh
```

## Running fmriprep-anatomical (includes freesurfer)

Note: this step uses and estimated **16hrs for processing time** per participant! So if all participants run at once (in our parallel cluster) it will still take a day to run.

#### Potential changes to script for your data
 
Most of the time the anatomical data includes the skull, but _sometimes_ people decide to share data where skull stripping has already happenned. If you data is **already skull stripped** than you need to add another flag `--skull-strip-t1w force` to the script `./code/01_fmriprep_anat_scinet.sh`



```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

# module load singularity/3.8.0 - singularity already on most nodes
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

## calculate the length of the array-job given
SUB_SIZE=1
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} code/01_fmriprep_anat_scinet.sh
```

## Running qsiprep

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/01_qsiprep_scinet.sh
```


## Submitting the fmriprep func step 

Running the functional step looks pretty similar to running the anat step. The time taken and resources needed will depend on how many functional tasks exists in the experiment - fMRIprep will try to run these in paralell if resources are available to do that.

Note -  the script enclosed uses some interesting extra opions:
 - it defaults to running all the fmri tasks - the `--task-id` flag can be used to filter from there
 - it is running `synthetic distortion` correction by default - instead of trying to work with the datasets available feildmaps - because feildmaps correction can go wrong - but this does require that the phase encoding direction is specificed in the json files (for example `"PhaseEncodingDirection": "j-"`).

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_fmriprep_func_scinet.sh
```


## Running qsirecon step1

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_qsirecon_step1_scinet.sh
```

## Running amico noddi

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_amico_noddi.sh
```
To complete the final step for amico noddi, you need a graphical user interface like VNC to connect to a remote desktop. This interface allows you to create the necessary figures and HTML files for QC purposes. To connect to the remote desktop, follow these steps:
1. [Install and connect to VNC using login nodes](https://docs.alliancecan.ca/wiki/VNC).
2. Open a terminal on VNC: navigate to Application > System Tools > MATE Terminal.
3. Run the following command:
   
```sh
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

source ./code/03_amico_VNC.sh
```

## Running freesurfer group analysis


```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

# module load singularity/3.8.0 - singularity already on most nodes
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

## calculate the length of the array-job given
SUB_SIZE=3
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} code/02_freesurfer_group_scinet.sh
```

If you do not plan to run stage 5 (data sharing) and only wish to obtain the FreeSurfer group outputs, follow these steps to run the FreeSurfer group merge code after completing the FreeSurfer group processing:

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

source ./code/freesurfer_group_merge_scinet.sh
```

## Running tractography
For multi-shell data, run the following code. For single-shell data, use the single-shell version of the code.

Multishell:
```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_tractography_multi_scinet.sh

```
Singleshell:
```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_tractography_single_scinet.sh

```


## Running ciftify-anat

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_ciftify_anat_scinet.sh
```


## Running xcp-d

If you're initiating the pipeline for the first time, it's crucial to acquire specific files from templateflow. Keep in mind that login nodes have internet access, while compute nodes operate in isolation. Therefore, make sure to download the required files as compute nodes lack direct internet connectivity. Here are the steps for pre-download:


```sh
#First load a python module
module load NiaEnv/2019b python/3.6.8

# Create a directory for virtual environments if it doesn't exist
mkdir ~/.virtualenvs
cd ~/.virtualenvs
virtualenv --system-site-packages ~/.virtualenvs/myenv

# Activate the virtual environment
source ~/.virtualenvs/myenv/bin/activate 

python3 -m pip install -U templateflow

# Run a Python script to import specified templates using the 'templateflow' package
python -c "from templateflow.api import get; get(['fsaverage','fsLR', 'Fischer344','MNI152Lin','MNI152NLin2009aAsym','MNI152NLin2009aSym','MNI152NLin2009bAsym','MNI152NLin2009bSym','MNI152NLin2009cAsym','MNI152NLin2009cSym','MNI152NLin6Asym','MNI152NLin6Sym'])"
```
```sh
#First load a python module
module load NiaEnv/2019b python/3.11.5

# Create a directory for virtual environments if it doesn't exist
mkdir ~/.virtualenvs
cd ~/.virtualenvs
virtualenv --system-site-packages ~/.virtualenvs/myenv

# Activate the virtual environment
source ~/.virtualenvs/myenv/bin/activate 

python3 -m pip install -U templateflow

# Run a Python script to import specified templates using the 'templateflow' package
python -c "from templateflow.api import get; get(['fsLR', 'Fischer344','MNI152Lin'])"
```
If you've already set up the pipeline before, bypass the previously mentioned instructions and proceed directly to executing the XCP pipeline:

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/03_xcp_scinet.sh
```

## Running xcp-noGSR

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/03_xcp_noGSR_scinet.sh
```

## Running enigma extract


```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

source ./code/ENIGMA_ExtractCortical.sh
```

## Running qsirecon step2

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/03_qsirecon_step2_scinet.sh
```

## Running enigma-dti

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## submit the array job to the queue
sbatch  ./code/04_enigma_dti_scinet.sh
```

## Running extract-noddi

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## submit the array job to the queue
sbatch  ./code/05_extract_noddi_scinet.sh
```


## Check tsv files

At any stages, before proceeding to the next stage and executing the codes for the subsequent phase, it's crucial to navigate to the data/local/logs folder and review the .tsv files for all pipelines from the previous stage. For instance, if you intend to execute stage 3 code, you must examine the .tsv files for both the fmriprep func and qsirecon pipelines. If no participants have encountered failures, you may proceed with running the next stage.

However, if any participant has failed, you need to first amend the data/local/bids/participants.tsv file by including the IDs of the failed participants. After rectifying the errors, rerun the pipeline with the updated participant list.


## Syncing the data with to the share directory

This step does calls some "group" level bids apps to build summary sheets and html index pages. It also moves a meta data, qc pages and a smaller subset of summary results into the data/share folder.

It takes about 10 minutes to run (depending on how much data you are synching). It could also be submitted.

```sh
## note step one is to make sure you are on one of the login nodes
ssh nia-login07

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

source ./code/05_extract_to_share.sh
```

Copy your folder into the shared spaced:

You need to change the "your_group_name" and put your group name there and then run the code!

```sh
cd ${SCRATCH}/SCanD_project

mkdir /scratch/a/arisvoin/arisvoin/mlepage/your_group_name
cp -r data/share  /scratch/a/arisvoin/arisvoin/mlepage/your_group_name/
```

# Appendix - Adding a test dataset from openneuro

#### (To test this repo - using an openneuro dataset)

To get an openneuro dataset for testing - we will use datalad

##### Loading datalad on SciNet niagara

```sh
## loading Erin's datalad environment on the SciNet system
module load git-annex/8.20200618 # git annex is needed by datalad
source /project/a/arisvoin/edickie/modules/datalad/0.15.5/build/bin/activate
```

##### Using datalad to install a download a dataset

```
cd ${SCRATCH}/SCanD_project/data/local/
datalad clone https://github.com/OpenNeuroDatasets/ds000115.git bids
```

Before running fmriprep anat get need to download/"get" the anat derivatives

```
cd bids
datalad get sub*/anat/*T1w.nii.gz
```
Before running fmriprep func - we need to download the fmri scans

```
cd bids
datalad get sub*/func/*
```

But - with this dataset - there is also the issue that this dataset is old enough that no Phase Encoding Direction was given for the fMRI scans - we really want at least to have this so we can run Synth Distortion Correction. So we are going to guess it..

To guess - we add this line into the middle of the top level json ().

```
"PhaseEncodingDirection": "j-",
```

note: now - thanks to the people at repronim - we can also add the repronim derivatives !

```{r}
cd ${SCRATCH}/SCanD_project/data/local/ls

datalad clone https://github.com/OpenNeuroDerivatives/ds000115-fmriprep.git fmriprep
datalad clone https://github.com/OpenNeuroDerivatives/ds000115-mriqc.git mriqc
```

getting the data files we actually use for downstream ciftify things
