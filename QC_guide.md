# QC guide

Here are guidelines to QC each pipeline results.

## fmriprep
### Anatomical Scans
**Things to check:**
1) Good BET (Brain Extraction Tool) Segmentation:
    * Red outline (skullstrip) doesn’t include skull, outlines the brain
    * Blue outline traces white matter area (lighter parts of brain)
  
      ![image](figures/Good_BET.png)

  
2) Good MNI wrap:
   * “Participant” brain only includes brain (no skull being included)
   * Make sure that the brain isn’t being stretched down into the cerebellum (indicative of BET segmentation issue)
  
     
 ![image](figures/Good_MNI.png)

   
### Functional Scans
**Things to check:**
1) Good EPI to T1 alignment:
    * The red/blue outlines should align with the functional image (darker/fuzzier image)
    * Bright white parts of the functional image should be mostly excluded from the red/blue outline
  
 ![image](figures/EPI_to_T1.png)

  
2) Good SDC correction:

The “After” Image should more closely align with the blue outline than the “Before” image

   ![image](figures/SDC_correction.png)


3) Clipping:

In some cases the bottom part of the cerebellum gets clipped, this is acceptable (a pass) but should still be annotated as having a Clipping issue. However, if any part of the cortex itself is clipped (bottom or top) this rating should always result in a fail.

   ![image](figures/Clipping.png)


4) EPI signal dropout:

Large signal dropout in the EPI image but not in the T1, which should always result in a Fail.

   ![image](figures/Signal_dropout.png)

## qsiprep

### Diffusion Section

1) b=0 reference image:
   
The brain mask creates a clear outline of the brain, with no significant deviations. Ensure to scroll through each of the sections, ensuring that the brain mask has correctly registered to the brain’s shape at each slice.

 ![image](figures/qsiprep_brainmask.png)

2) DWI sampling Scheme:
   
Compare the two images by rotating the images around and ensuring that they both generally make out the shape of a ball as seen below.

 ![image](figures/qsiprep_qspace.png)
    

3) b=0 to anatomical reference registration:
   
This is the final image output of the pipeline, so it has been motion corrected, denoised, bias corrected, etc. So, this is the first image you should be checking to see if anything went wrong with those steps, namely if it has been distorted too much, cut off, etc. In this case, the images clearly resemble the shape of a brain and there are little to no artifacts visible outside of the brain.

   ![image](figures/qsiprep_motion.png)
    
4) DWI summary:

In the FD plot, look for large or frequent spikes, which indicate sudden head movements during the scan. Consistently high FD values or many volumes above common thresholds (e.g., ~0.5 mm) suggest excessive motion and reduced data quality.

   ![image](figures/qsiprep_FD.png) 
   

## ciftify

**Things to check:**

1) Make sure there is no black images, which happens if recon-all failed very early in the pipeline.

 ![image](figures/ciftify_1.png)
 
2) Aparc image (examples of QC fails):

* check the quality of image. For a very poor quality anatomical, the surface will look shrivelled up like the example below.

 ![image](figures/ciftify_2.png)
 
* If the gray matter is missing part of the occipital lobe, the back of the brain will look split apart on the bottom view (far right).

 ![image](figures/ciftify_3.png)
 
* For this participant, the surface reconstruction in the aparc view looks jagged (especially in the orbital frontal cortex).

 ![image](figures/ciftify_4.png)
 
3) White and pial surfaces:

 A key place to look are the two temporal poles. Surface reconstruction in these area can fail. Here is an example:

 ![image](figures/ciftify_5.png)
 
