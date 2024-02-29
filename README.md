# SCanD_project_GMANJ

This is a base repo for the Schizophrenia Canadian Neuroimaging Database (SCanD) codebase. It is meant to be folked/cloned for every SCanD dataset

General folder structure for the repo (when all is run)

```
${BASEDIR}
├── code                         # a clone of this repo
│   └── ...    
├── containers                   # the singularity image are copied or linked to here
│   ├── fmriprep-20.2.7.simg 
│   ├── mriqc-22.0.6.simg simg
│   ├── qsiprep_0.16.0RC3.simg
│   ├── fmriprep_ciftity-v1.3.2-2.3.3.simg
│   ├── tbss2.simg 
│   └── xcp_d-0.6.0.simg
├── data
│   ├── local                    # folder for the "local" dataset
│   │   ├── bids                 # the defaced BIDS dataset
│   │   ├── mriqc                # mriqc derivatives
│   │   ├── fmriprep             # fmriprep derivatives
│   │   ├── freesurfer           # freesurfer derivative - generated during fmriprep
│   │   ├── qsiprep              # full qsiprep derivatives
│   │   ├── ciftify              # ciftify derivatives
│   │   ├── parcellated          # parcellation-xcp derivatives
│   │   ├── parcellated_ciftify  # parcellation-ciftify derivatives
│   │   ├── ENIGMA_extract       # extracted cortical and subcortical csv files
│   │   └── xcp_d                # xcp
│   |
│   └── share                    # folder with a smaller subset ready to share
│       ├── mriqc                # contains only qc images and metadata
│       ├── fmriprep             # contains only qc images and metadata
│       ├── qsiprep              # contains only qc images and metadata
│       ├── ciftify              # contains only qc images and metadata
│       ├── parcellated           # contains only qc images and metadata
│       ├── parcellated_ciftify           # contains only qc images and metadata
│       ├── ENIGMA_extract       # extracted cortical and subcortical csv files
│       └── xcp_d                # contains xcp results
├── logs                         # logs from jobs run on cluster                 
|── README.md
|── work                         #work directory for xcp-d
|── LICENSE
|──stage_1.sh
|──stage_2.sh
|──stage_3.sh
|──stage_4.sh
|──stage_5.sh
|── Workflow Automation_stages.md
└── templates                  # an extra folder with pre-downloaded fmriprep templates (see setup section)
    └── parcellations
        ├── README.md
        └── tpl-fsLR_res-91k_atlas-Glasser_dseg.dlabel.nii
    
```

Currently this repo is going to be set up for running things on SciNet Niagara cluster - but we can adapt later to create local set-ups behind hospital firewalls if needed.

# The general overview of what to do



| stage |  #	| Step	|   How Long Does it take to run? 	|
|---    |---	|---	|---	|
| stage 0|   0a	|  [Organize your data into BIDS..](#organize-your-data-into-bids) 	|   As long as it takes	|
|^ |   0b	|  [Deface the BIDS data (if not done during step 1)](#deface-the-bids-data-if-not-done-during-step-1) 	|   	|
|^ |   0c	|   [Setting up the SciNet environment](#Setting-your-scinet-enviromentcodeand-data)	| 30 minutes in terminal 	|
|^ |   0d	|   [Move you bids data to the correct place and add lables to participants.tsv file](#Put-your-bids-data-into-the-datalocal-folder-and-add-lables-to-participantstsv-file)	| depends on time to transfer data to SciNet  	|
|stage 1|   01a	|  [Run MRIQC](#Running-mriqc) 	|  16 hours on slurm 	|
|^|   01b	|  [Run fMRIprep anat](#Running-fmriprep-anatomical-includes-freesurfer) 	|   16 hours on slurm	|
|^ |   01c	|  [Run QSIprep](#Running-qsiprep) 	|   6 hours on slurm	|
|stage 2|   02a	|  [Run fMRIprep func](#Submitting-the-fmriprep-func-step) 	|  20 hours of slurm 	|
|^ |   02b	|  [Run qsirecon ](#Running-qsirecon) 	|  2 hours of slurm 	|
|stage 3 |   03a	|  [Run ciftify-anat](#Running-ciftify-anat) 	|  10 hours on slurm 	|
|^ |   03b	|  [Run xcp-d](#Running-xcp-d) 	|  10 hours on slurm 	|
|^ |   03c	|  [Run ENIGMA extract](#Running-enigma-extract) 	|  5 min in terminal	|
|^ |   03d	|  [Run enigma-dti](#Running-enigma-dti) 	|  1 hours on slurm	|
|stage 4 |   04a	|  [Running the parcellation-xcp step](#Running-the-parcellation-xcp-step) 	|   20 mins on slurm	|
|^ |   04b	|  [Running the parcellation-ciftify step](#Running-the-parcellation-ciftify-step) 	|   20 mins on slurm	|
|stage 5 |   05a	|  [Run extract and share to move to data to sharable folder](#Syncing-the-data-with-to-the-share-directory) 	|   30 min in terminal	|

## Organize your data into BIDS

This is the longest - most human intensive - step. But it will make everything else possible! BIDS is really a naming convention for your MRI data that will make it easier for other people the consortium (as well as the software) to understand what your data is (what scan types, how many participants, how many sessions..ect). Converting to BIDS may require renaming and/or reorganizing your current data. No coding is required, but there now a lot of different software projects out there to help out with the process.

For amazing tools and tutorials for learning how to BIDS convert your data, check out the [BIDS starter kit](https://bids-standard.github.io/bids-starter-kit/).


## Deface the BIDS data (if not done during step 1)

A useful tool is [this BIDSonym BIDS app](https://peerherholz.github.io/BIDSonym/).

## Setting your SciNet enviroment/code/and data

### Cloning this Repo

```sh
cd $SCRATCH
git clone https://github.com/GhazalehManj/SCanD_project_GMANJ.git
```

## Run the software set-up script

```sh
cd ${SCRATCH}/SCanD_project_GMANJ
source code/00_setup_data_directories.sh
```

### Put your bids data into the data/local folder and add lables to participants.tsv file

We want to put your data into:

```
./data/local/bids
```
After organizing the bids folder, proceed to populate the participant labels, such as 'sub-CMH0047' within the 'ScanD_project_GMANJ/data/local/bids/participants.tsv' file.

#### For a test run of the code

For a test run of this available code you can work with a test dataset from open neuro - [check out the appendix for add the code to download test data](#appendix---adding-a-test-dataset-from-openneuro) . 

#### Your own data - continue from here

You can do this by either copying "scp -r", linking `ln -s` or moving the data to this place - it's your choice.

To copy the data from another computer/server you should be on the datamover node:


```sh
ssh <cc_username>@niagara.scinet.utoronto.ca
ssh nia-dm1
rsync -av <local_server>@<local_server_address>:/<local>/<server>/<path>/<bids> ${SCRATCH}/SCanD_project_GMANJ/data/local/
```

To link existing data from another location on SciNet Niagara to this folder:

```sh
ln -s /your/data/on/scinet/bids ${SCRATCH}/SCanD_project_GMANJ/data/local/bids
```


## Running mriqc


```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull         #in case you need to pull new code

## calculate the length of the array-job given
SUB_SIZE=10
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"


## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/01_mriqc.sh
```

## Running fmriprep-anatomical (includes freesurfer)

Note: this step uses and estimated **16hrs for processing time** per participant! So if all participants run at once (in our parallel cluster) it will still take a day to run.

#### Potential changes to script for your data
 
Most of the time the anatomical data includes the skull, but _sometimes_ people decide to share data where skull stripping has already happenned. If you data is **already skull stripped** than you need to add another flag `--skull-strip-t1w force` to the script `./code/01_fmriprep_anat_scinet.sh`



```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

# module load singularity/3.8.0 - singularity already on most nodes
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
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
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## figuring out appropriate array-job size
SUB_SIZE=2 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
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
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## figuring out appropriate array-job size
SUB_SIZE=2 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_fmriprep_func_scinet.sh
```


## Running qsirecon

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/02_qsirecon_scinet.sh
```

## Running ciftify-anat

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## figuring out appropriate array-job size
SUB_SIZE=8 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/03_ciftify_anat_scinet.sh
```


## Running xcp-d

If you're initiating the pipeline for the first time, it's crucial to acquire specific files from templateflow. Keep in mind that login nodes have internet access, while compute nodes operate in isolation. Therefore, make sure to download the required files as compute nodes lack direct internet connectivity. Here are the steps for pre-download:


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
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/03_xcp_scinet.sh
```


## Running enigma extract


```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

source ./code/03_ENIGMA_ExtractCortical.sh
```


## Running enigma-dti

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## submit the array job to the queue
sbatch  ./code/03_enigma_dti_scinet.sh
```


## Running the parcellation-xcp step

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## figuring out appropriate array-job size
SUB_SIZE=10 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_DTSERIES=$(ls -1d ./data/local/xcp_d/sub*/ses*/func/*dtseries* | wc -l)
array_job_length=$(echo "$N_DTSERIES/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/04_parcellate_xcp_scinet.sh
```

## Running the parcellation-ciftify step

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

## figuring out appropriate array-job size
SUB_SIZE=10 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ./data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
sbatch --array=0-${array_job_length} ./code/04_parcellate_ciftify_scinet.sh
```
## Syncing the data with to the share directory

This step does calls some "group" level bids apps to build summary sheets and html index pages. It also moves a meta data, qc pages and a smaller subset of summary results into the data/share folder.

It takes about 10 minutes to run (depending on how much data you are synching). It could also be submitted.

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project_GMANJ
git pull

source ./code/05_extract_to_share.sh
```

# Appendix - Adding a test dataset from openneuro

#### (To test this repo - using an openneuro dataset)

To get an openneuro dataset for testing - we will use datalad

##### Loading datalad on SciNet niagara

```sh
## loading Erin's datalad environment on the SciNet system
module load git-annex/8.20200618 # git annex is needed by datalad
module use /project/a/arisvoin/edickie/modules #this let's you read modules from Erin's folder
module load datalad/0.15.5 # this is the datalad module in Erin's folder
```

##### Using datalad to install a download a dataset

```
cd ${SCRATCH}/SCanD_project_GMANJ/data/local/
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
cd ${SCRATCH}/SCanD_project_GMANJ/data/local/ls

datalad clone https://github.com/OpenNeuroDerivatives/ds000115-fmriprep.git fmriprep
datalad clone https://github.com/OpenNeuroDerivatives/ds000115-mriqc.git mriqc
```

getting the data files we actually use for downstream ciftify things
