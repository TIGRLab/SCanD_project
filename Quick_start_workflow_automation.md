# Workflow automation (stage scripts)

Use the `stage_*.sh` scripts at the repository root to run pipelines one stage at a time. Each script prompts you for which pipelines to submit, so you can skip diffusion or functional steps when they do not apply to your dataset.

**Before the next stage:** Review the latest Neurobagel processing status under `Neurobagel/derivatives/.processing_statuses/processing_status-*.tsv` (or `data/share/processing_status.tsv` after stage 6) for all pipelines from the previous stage. For example, before stage 3, confirm stage 2 pipelines completed successfully. You can upload the status file to [Neurobagel Digest](https://digest.neurobagel.org/) for filtering and summary views. If any participant failed, remove those IDs from `data/local/bids/participants.tsv` (keep only subjects you want to rerun), fix the underlying issue, and resubmit the affected pipeline.

## Stage 0 (setup BIDS folder and SciNet environment)

After setting up the SciNet environment and organizing your BIDS folder and `participants.tsv` file, run the stage scripts below.

## Stage 1 (mriqc, qsiprep, fmriprep_fit, freesurfer, smriprep, magetbrain_init)

```sh
cd ${SCRATCH}/SCanD_project
git pull

source ./stage_1.sh
```

## Stage 2 (ciftify_anat, fmriprep_apply, freesurfer_parcellate, magetbrain_register, qsirecon_FSL, amico_noddi, tractography)

```sh
cd ${SCRATCH}/SCanD_project
git pull

source ./stage_2.sh
```

## Stage 3 (xcp_d, xcp_noGSR, magetbrain_vote, qsirecon_dtifit, noddireg, glm_surface)

```sh
cd ${SCRATCH}/SCanD_project
git pull

source ./stage_3.sh
```

## Stage 4 (enigma_dti)

```sh
cd ${SCRATCH}/SCanD_project
git pull

source ./stage_4.sh
```

## Stage 5 (noddi_extract)

```sh
cd ${SCRATCH}/SCanD_project
git pull

source ./stage_5.sh
```

## Stage 6 (extract data to share folder)

```sh
cd ${SCRATCH}/SCanD_project
git pull

source ./stage_6.sh
```

## Consortium handoff

After stage 6, verify `data/share` against [share_folder.md](share_folder.md). Once the checklist passes, copy results to the shared space. Replace `<groupName_studyName>` with your consortium group and study identifier (for example, `CMH_study2024`):

```sh
cd ${SCRATCH}/SCanD_project

mkdir /scratch/arisvoin/shared/<groupName_studyName>
cp -r data/share /scratch/arisvoin/shared/<groupName_studyName>/
```
