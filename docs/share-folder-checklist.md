# Share folder

Use this checklist to verify `data/share` after stage 6, before copying results to the consortium shared space. For visual QC of pipeline HTML reports and figures, see [qc-guide.md](qc-guide.md).

**How to use this checklist**

1. Confirm each top-level folder below exists under `${BASEDIR}/data/share`.
2. Spot-check one or two subjects per pipeline for expected QC images and metadata.
3. Confirm root-level TSV files (`participants.tsv`, `manifest.tsv`, `processing_status.tsv`, and the fmriprep/qsiprep method sidecars) are present and non-empty.

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
│   ├── dataset_description.json
│   ├── *dseg.tsv
│   ├── sub-*_*.html
│   └── sub-<label>/
│       ├── sub-<label>_run-1_desc-preproc_T1w.nii.gz
│       ├── sub-<label>_run-1_desc-brain_mask.nii.gz
│       ├── figures/
│       │   ├── sub-<label>_ses-<session>_task-*_run-*_desc-sdc_bold.svg
│       │   ├── sub-<label>_ses-<session>_task-*_run-*_desc-coreg_bold.svg
│       │   └── sub-<label>_run-1_desc-reconall_T1w.svg
│       └── sourcedata/freesurfer/sub-<label>/scripts/recon-all-status.log
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
│   └── sub-<label>/
│       ├── figures/
│       │   ├── sub-<label>_ses-<session>_icvf_mean_qc.png
│       │   ├── sub-<label>_ses-<session>_od_mean_qc.png
│       │   ├── sub-<label>_ses-<session>_isovf_mean_qc.png
│       │   ├── sub-<label>_ses-<session>_desc-4S1056Parcels_model-noddi_mdp-icvf_qa.png
│       │   ├── sub-<label>_ses-<session>_desc-4S1056Parcels_model-noddi_mdp-od_qa.png
│       │   └── sub-<label>_ses-<session>_desc-dsegtissue_model-noddi_density.png
│       ├── sub-<label>_ses-<session>_desc-4S1056Parcels_model-noddi_results.tsv
│       ├── sub-<label>_ses-<session>_acq-multishelldir92_run-1_space-T1w_dwiref.nii.gz
│       └── sub-<label>_space-T1w_ref-dwiref_desc-4S1056Parcels_dseg.nii.gz
├── participants.tsv
├── manifest.tsv
├── processing_status.tsv
├── processing_status_fmriprep.tsv
│   └── participant_id, session_id, fmriprep_method columns
├── processing_status_qsiprep.tsv
│   └── participant_id, session_id, qsiprep_sdc_method columns
├── qsiprep/0.22.0
│   ├── qsiprep_metrics.csv
│   ├── *.json
│   ├── sub-*_*.html
│   └── sub-<label>/
│       └── figures/
│           ├── sub-<label>_seg_brainmask.svg
│           ├── sub-<label>_t1_2_mni.svg
│           ├── sub-<label>_ses-<session>_acq-multishelldir92_run-1_desc-sdc_b0.svg
│           └── sub-<label>_ses-<session>_acq-multishelldir92_run-1_coreg.svg
├── smriprep/25.2.4
│   └── QC images and metadata for each scan
├── tractify
│   └── connectivity.mat file for each scan
├── xcp_d/0.7.3
│   └── QC images and metadata for each scan
└── xcp_noGSR
    └── QC images and metadata for each scan
```

After the checklist passes, follow the consortium handoff steps in [quick-start-workflow.md](quick-start-workflow.md) or the README stage 6 section.
