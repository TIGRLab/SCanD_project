# QC guide

Here are guidelines to QC each pipeline results.

## fmriprep
### Anatomical Scans
**Things to check:**
1) Good Brain Extraction Segmentation:
    * Red outline (skullstrip) doesn’t include skull, outlines the brain
    * Blue outline traces white matter area (lighter parts of brain)
  
      <img width="683" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/44712162-3d37-4ebf-bc42-2180dcdf6db5">

  
2) Good MNI wrap:
   * “Participant” brain only includes brain (no skull being included)
   * Make sure that the brain isn’t being stretched down into the cerebellum (indicative of BET segmentation issue)
  
     
<div style="text-align:center">
    <img width="728" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/3fa6435f-ee59-4480-90ab-cf232037078d">
</div>



     
### Anatomical Scans

## qsiprep

## ciftify
