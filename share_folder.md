# Share folder

Here is a checklist for the share folder results.


```
${BASEDIR}/data/share
├── amico_noddi
│   ├── noddi_roi                      
│   └── files for each subject
├── ciftify                        
│   └── qc_recon_all
├── enigmaDTI                   
│   ├── ADskel_qc_index.html
│   ├── FAskel_qc_index.html
│   ├── group_enigmaDTI_nvoxels.csv
│   ├── group_enigmaDTI_AD.csv
│   ├── group_enigmaDTI_FA.csv
│   ├── group_enigmaDTI_MD.csv
│   ├── group_enigmaDTI_RD.csv
│   ├── MDskel_qc_index.html
│   ├── RDskel_qc_index.html
│   └── files for each subject
├── fmriprep/25.2.4
│   └── QC images and metadata for each scan
├── glm/0.0.1
│   └── GLM model outputs, contrasts, and QC images per subject
├── freesurfer_group
│   ├── group-level FreeSurfer metrics (aseg, euler, aparc thickness)
│   ├── Schaefer2018 parcellation metrics (100–1000 parcels: thickness, surfacearea, grayvol)
│   └── ENIGMA_extract (ENIGMA formatted outputs)
├── magetbrain
│   ├── fusion (output labels)
│   ├── input (all subject brain files)
│   └── QC (QC images and volume.csv files)
├── mriqc/24.0.0
│   ├── dataset_description.json
│   ├── group_bold.tsv
│   ├── group_T1w.tsv
│   └── group_T2w.tsv
├── noddireg
│   └── .tsv file: parcel-wise summary statistics of NODDI microstructural metrics
├── participants.tsv
├── manifest.tsv
├── processing_status.tsv
├── processing_status_fmriprep.tsv
├── processing_status_qsiprep.tsv
├── qsiprep/0.22.0
│   ├── qsiprep_metrics.csv
│   └── QC images and metadata for each scan
├── smriprep/25.2.4
│   └── QC images and metadata for each scan
├── tractify
│   └── connectivity.mat file for each scan         
├── xcp-d/0.7.3
│   └── QC images and metadata for each scan
└── xcp-noGSR
    └── QC images and metadata for each scan
