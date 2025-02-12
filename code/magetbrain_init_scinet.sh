mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input/subjects
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input/subjects/brains
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input/templates
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input/templates/brains
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input/atlases
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input/atlases/brains
mkdir $SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data/input/atlases/labels


export MAGetbrain_DIR=$SCRATCH/SCanD_project/data/local/MAGeTbrain/magetbrain_data
export BIDS_DIR=$SCRATCH/SCanD_project/data/local/bids
export FMRIPREP_DIR=$SCRATCH/SCanD_project/data/local/derivatives/fmriprep/23.2.3/

cp -r $BIDS_DIR/$subject/*/anat/*T1w.nii.gz  $MAGetbrain_DIR/input/subjects/brains/
cp -r $FMRIPREP_DIR/data/local/derivatives/fmriprep/23.2.3/$subject/ses-*/func/*space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz  $MAGetbrain_DIR/input/templates/brains/

gunzip $MAGetbrain_DIR/input/subjects/brains/*.nii.gz
gunzip $MAGetbrain_DIR/input/templates/brains/*.nii.gz


nii2mnc $MAGetbrain_DIR/input/subjects/brains/*T1w.nii \
        $MAGetbrain_DIR/input/subjects/brains/*T1w.mnc

nii2mnc $MAGetbrain_DIR/input/templates/brains/*space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz \
        $MAGetbrain_DIR/input/templates/brains/*space-MNI152NLin2009cAsym_desc-preproc_bold.mnc

# add subject selection
#add atlases
#init code subjects if posiible
#clean code
