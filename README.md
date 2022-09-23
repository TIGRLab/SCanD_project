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

## To test this repo - using an openneuro dataset

To get an openneuro dataset for testing - we will use datalad


## loading datalad on SciNet niagara
```sh
## loading Erin's datalad environment on the SciNet system
module load git-annex/8.20200618 # git annex is needed by datalad
module use /project/a/arisvoin/edickie/modules #this let's you read modules from Erin's folder
module load datalad/0.15.5 # this is the datalad module in Erin's folder
```

## using datalad to install a download a dataset

```
mkdir -p ${BASEDIR}/data/local/
cd ${BASEDIR}/data/local/
datalad install https://github.com/OpenNeuroDatasets/ds000102.git bids
```

note: now - thanks to the people at repronim - we can also add the repronim derivatives !

```{r}
datalad install https://github.com/OpenNeuroDerivatives/ds000102-fmriprep.git
datalad install https://github.com/OpenNeuroDerivatives/ds000102-mriqc.git
```
