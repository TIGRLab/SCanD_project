# parcellations

CIFTI atlases (`*.dlabel.nii`) in fsLR 91k space, plus matching label tables (`*.tsv`).

They come from [PennLINC/AtlasPack](https://github.com/PennLINC/AtlasPack) (same atlases used by XCP-D).

## CIFTI maps

- `tpl-fsLR_res-91k_atlas-Glasser_dseg.dlabel.nii` — Glasser cortex (360 ROI)
- `tpl-fsLR_res-91k_atlas-Gordon_dseg.dlabel.nii` — Gordon cortex (333 ROI)
- `tpl-fsLR_res-91k_atlas-4S156Parcels_dseg.dlabel.nii` … `atlas-4S1056Parcels` — 4S atlases (Schaefer cortex + subcortex/cerebellum; 156–1056 parcels)

## Label tables

- `atlas-Glasser_dseg.tsv`, `atlas-Gordon_dseg.tsv`, `atlas-4S*Parcels_dseg.tsv` — labels for the CIFTI maps above
- `atlas-Schaefer7N100_dseg.tsv`, `atlas-Schaefer7N400_dseg.tsv`, `atlas-Schaefer7N1000_dseg.tsv` — Schaefer 7-network labels
- `atlas-Hammers_dseg.tsv` — Hammersmith atlas labels
- `desc-FreeSurferAll_dseg.tsv` — FreeSurfer LUT (used for aparc+aseg / wmparc)

## Citations

Glasser, Matthew F., et al. 2016. “A Multi-Modal Parcellation of Human Cerebral Cortex.” Nature 536 (7615): 171–78.

Gordon, Evan M., et al. 2016. “Generation and Evaluation of a Cortical Area Parcellation from Resting-State Correlations.” Cerebral Cortex 26 (1): 288–303.

Schaefer, Alexander, et al. 2018. “Local-Global Parcellation of the Human Cerebral Cortex from Intrinsic Functional Connectivity MRI.” Cerebral Cortex 28 (9): 3095–3114.
