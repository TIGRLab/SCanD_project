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
  
<img width="775" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/544b7301-677d-4b9d-bc1b-0f1cb58b994d">


  
2) Good SDC correction:
* The “After” Image should more closely align with the blue outline than the “Before” image

  <img width="763" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/0437fb6e-dd61-4185-a278-5ca663bc3e76">


3) Clipping:
   In some cases the bottom part of the cerebellum gets clipped, this is acceptable (a pass) but should still be annotated as having a Clipping issue. However, if any part of the cortex itself is clipped (bottom or top) this rating should always result in a fail.

   <img width="800" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/cb6ec006-fdb2-4bdd-886d-5d3df2ae5aca">


5) EPI signal dropout:
   Large signal dropout in the EPI image but not in the T1, which should always result in a Fail.

   ![image](https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/00eca287-7d1a-4f61-99cb-07376bcf7754)


      
## qsiprep

## ciftify
