# SCanD_project

This is a base repo for the Schizophrenia Canadian Neuroimaging Database (SCanD) codebase. It is meant to be folked/cloned for every SCanD dataset

General folder structure for the repo (when all is run)

```
${BASEDIR}
├── code                         # a clone of this repo
│   └── ...       
├── containers
│   └── fmriprep-20.2.7.simg     # the singularity image are copied or linked to here
├── data
|   ├──local                   # folder for the dataset
│   |  ├── bids                # the bids data is the data downloaded from openneuro
│   |  ├── derived             # holds derivatives derived from the bids data
│   |  ├── fmriprep            # full fmriprep outputs
│   |  ├── ciftify             # full ciftify outputs
│   |  ├── cifti_clean         # full cleaned dtseries
│   |  └── mriqc               # full mriqc outputs
│   └──share                   # logs from jobs run on cluster
│      ├── parcellated         # the bids data is the data downloaded from openneuro
│   └── logs                   # logs from jobs run on cluster
└── templates                  # an extra folder with pre-downloaded fmriprep templates (see setup section)

```

Currently this repo is going to be set up for running things on SciNet Niagara cluster - but we can adapt later to create local set-ups behind hospital firewalls if needed.

# The general overview of what to do

1. Organize your data into BIDS..
2. Deface the BIDS data (if not done during step 1)
3. Setting your SciNet enviroment/code/and data
   1. Clone the Repo
   2. Run the software set-up script (takes a few seconds)
   3. Copy or link your bids data to this folder
4. Run MRIQC
5. Run fmriprep
6. Run ciftify
7.  Run ciftify_clean and parcellate
8.  Run the scripts to extract sharable data into the sharable folder 

## Organize your data into BIDS

This is the longest - most human intensive - step. But it will make everything else possible! BIDS is really a naming convention for your MRI data that will make it easier for other people the consortium (as well as the software) to understand what your data is (what scan types, how many participants, how many sessions..ect). Converting to BIDS may require renaming and/or reorganizing your current data. No coding is required, but there now a lot of different software projects out there to help out with the process.

For amazing tools and tutorials for learning how to BIDS convert your data, check out the [BIDS starter kit](https://bids-standard.github.io/bids-starter-kit/).

## Deface the BIDS data (if not done during step 1)

(Instructions/code TBA)

## Setting your SciNet enviroment/code/and data

### Cloning this Repo

```sh
cd $SCRATCH
git clone https://github.com/TIGRLab/SCanD_project.git
```

### Run the software set-up script

```sh
source ${SCRATCH}/SCanD_project/code/00_setup_data_directories.sh
```

### put your bids data into the data/local folder

We want to put your data into:

```
./data/local/bids
```

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

#### (To test this repo - using an openneuro dataset)

To get an openneuro dataset for testing - we will use datalad

##### loading datalad on SciNet niagara

```sh
## loading Erin's datalad environment on the SciNet system
module load git-annex/8.20200618 # git annex is needed by datalad
module use /project/a/arisvoin/edickie/modules #this let's you read modules from Erin's folder
module load datalad/0.15.5 # this is the datalad module in Erin's folder
```

##### using datalad to install a download a dataset

```
cd ${SCRATCH}/SCanD_project/data/local/
datalad clone https://github.com/OpenNeuroDatasets/ds000115.git bids
```

note: now - thanks to the people at repronim - we can also add the repronim derivatives !

```{r}
cd ${SCRATCH}/SCanD_project/data/local/ls

datalad clone https://github.com/OpenNeuroDerivatives/ds000115-fmriprep.git fmriprep
datalad clone https://github.com/OpenNeuroDerivatives/ds000115-mriqc.git mriqc
```

getting the data files we actually use for downstream ciftify things

```sh

```

## Running fmriprep-anatomical (includes freesurfer)

Note: this step uses and estimated **24hrs for processing time** per participant! So if all participants run at once (in our parallel cluster) it will still take a day to run.

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## don't forget to make sure that $BASEDIR and $OPENNEURO_DSID are defined..

# module load singularity/3.8.0 - singularity already on most nodes
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull         #in case you need to pull new code

## calculate the length of the array-job given
SUB_SIZE=5
N_SUBJECTS=$(( $( wc -l ${SCRATCH}/SCanD_project/data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
cd ${SCRATCH}/SCanD_project
sbatch --array=0-${array_job_length} ${SCRATCH}/SCanD_project/code/01_fmriprep_anat_scinet.sh
```
### submitting the fmriprep func step (scinet)

Running the functional step looks pretty similar to running the anat step. The time taken and resources needed will depend on how many functional tasks exists in the experiment - fMRIprep will try to run these in paralell if resources are available to do that.

Note -  the script enclosed uses some interesting extra opions:
 - it defaults to running all the fmri tasks - the `--task-id` flag can be used to filter from there
 - it is running `synthetic distortion` correction by default - instead of trying to work with the datasets available feildmaps - because feildmaps correction can go wrong.

```sh
## note step one is to make sure you are on one of the login nodes
ssh niagara.scinet.utoronto.ca

## don't forget to make sure that $BASEDIR and $OPENNEURO_DSID are defined..

module load singularity/3.8.0
## go to the repo and pull new changes
cd ${SCRATCH}/SCanD_project
git pull

## figuring out appropriate array-job size
SUB_SIZE=1 # for func the sub size is moving to 1 participant because there are two runs and 8 tasks per run..
N_SUBJECTS=$(( $( wc -l ${SCRATCH}/SCanD_project/data/local/bids/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
echo "number of array is: ${array_job_length}"

## submit the array job to the queue
cd ${SCRATCH}/SCanD_project
sbatch --array=0-${array_job_length} ./code/02_fmriprep_func_scinet.sh
```

