# QC guide

Here are guidelines to QC each pipeline results.

## fmriprep
### Anatomical Scans
**Things to check:**
1) Good BET (Brain Extraction Tool) Segmentation:
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

The “After” Image should more closely align with the blue outline than the “Before” image

  <img width="763" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/0437fb6e-dd61-4185-a278-5ca663bc3e76">



3) Clipping:

In some cases the bottom part of the cerebellum gets clipped, this is acceptable (a pass) but should still be annotated as having a Clipping issue. However, if any part of the cortex itself is clipped (bottom or top) this rating should always result in a fail.

   <img width="800" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/cb6ec006-fdb2-4bdd-886d-5d3df2ae5aca">



4) EPI signal dropout:

Large signal dropout in the EPI image but not in the T1, which should always result in a Fail.

   ![image](https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/00eca287-7d1a-4f61-99cb-07376bcf7754)


      
## qsiprep

**Things to check:**

1) Good motion and distortion corrected DWI file:
   
This is the final image output of the pipeline, so it has been motion corrected, denoised, bias corrected, etc. So, this is the first image you should be checking to see if anything went wrong with those steps, namely if it has been distorted too much, cut off, etc. In this case, the images clearly resemble the shape of a brain and there are little to no artifacts visible outside of the brain.


   <img width="757" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/0855f9be-0d55-4a5f-84c0-615205c8554e">

2) Good framewise displacement graph:

The y axis has a relatively low maximum value, indicating overall lower levels of motion. The two traces do not significantly diverge from each other, with generally similar peaks and troughs.


   <img width="739" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/d45c1375-5475-49d6-bf25-67d944e7567a">

3) Good Q-space sampling:
   
Compare the two images by rotating the images around and ensuring that they both generally make out the shape of a ball as seen below.

   ![image](https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/a171bc7c-9d33-4884-9002-ccc16e3251fc)

4) Good brain mask:
   
The brain mask creates a clear outline of the brain, with no significant deviations. Ensure to scroll through each of the sections, ensuring that the brain mask has correctly registered to the brain’s shape at each slice.

   <img width="746" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/8d6d4641-a407-4391-9bfc-2df81cafe377">

5) Good Tensor image:
    
Each of the different directions as indicated by the different colors need to be localized to their own locations and discernible from each other. For example the sagittal section shows a clear separation between the green and red tracts.

   <img width="750" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/d1793098-01e0-44b6-af85-66f64dec4506">

## ciftify

**Things to check:**

1) EPI to T1 registration (MNI):
  
Apparent alignment issues between the MNI-transformed version of the EPI and T1 data (below). Note that this may be a consequence of the visualization method. EPI to T1 alignment should be double checked via fMRIPrep (and cross-referenced to fMRIPrep participants.tsv). 
   
<img width="754" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/57278410-d787-4fc9-b264-17636783a4df">

2) Seed-network maps:

Seed correlation maps (i.e DMN as below) do not show any brain functional network structure.
This is not a real issue. The data displayed by Ciftify has not been cleaned, the preferred approach would be to clean your data first then visualize seed correlation maps.

 <img width="766" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/b78f80b8-52ea-42fb-8137-4b29e6c13417">

