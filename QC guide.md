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

1) Make sure there is no black images, which happens if recon-all failed very early in the pipeline.

<img width="902" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/a2d387a6-ffc9-4919-9375-5153659ad260">

2) Aparc image (examples of QC fails):

* check the quality of image. For a very poor quality anatomical, the surface will look shrivelled up like the example below.

<img width="907" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/e2beb8b8-7355-46c2-ae5f-3dcb952ae5bc">

* If the gray matter is missing part of the occipital lobe, the back of the brain will look split apart on the bottom view (far right).

<img width="917" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/296f34da-6784-4ffb-807f-a684acafb7e8">

* For this participant, the surface reconstruction in the aparc view looks jagged (especially in the orbital frontal cortex).

<img width="915" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/a518d488-9bcb-4fb5-a81a-a0423cc22d7d">

3) White and pial surfaces:

 A key place to look are the two temporal poles. Surface reconstruction in these area can fail. Here is an example:

<img width="903" alt="image" src="https://github.com/GhazalehManj/SCanD_project_GMANJ/assets/126309136/99b91b48-c8af-4f7e-93ac-1fa18d9fb1c6">
