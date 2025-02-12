
mkdir magetbrain_data

cp -r /archive/data/PREDICTS/data/bids/sub-CMH00000098/ses-01/anat/sub-CMH00000098_ses-01_T1w.nii.gz  magetbrain_data/input/subjects/brains/

gunzip magetbrain_data/input/subjects/brains/sub-CMH00000098_ses-01_T1w.nii.gz


nii2mnc magetbrain_data/input/subjects/brains/sub-CMH00000098_ses-01_T1w.nii \
        magetbrain_data/input/subjects/brains/sub-CMH00000098_ses-01_T1w.mnc
