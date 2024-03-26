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
  
     
![image](https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/d26897b7-6d66-4820-8eb5-3eaf062375b2)

   
### Functional Scans
**Things to check:**
1) Good EPI to T1 alignment:
    * The red/blue outlines should align with the functional image (darker/fuzzier image)
    * Bright white parts of the functional image should be mostly excluded from the red/blue outline
  
      <img width="826" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/28d06ded-7221-46a9-ac01-2c4f02fa61b6">

  
2) Good SDC correction:
* The “After” Image should more closely align with the blue outline than the “Before” image

  <img width="763" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/0437fb6e-dd61-4185-a278-5ca663bc3e76">

      
## qsiprep

## ciftify
