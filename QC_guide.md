# QC Guide

Here are guidelines to QC each pipeline results.

Reference screenshots are not bundled in this repository; use the criteria below when reviewing HTML reports and figures under `data/local/derivatives/`.

---

## fmriprep

### Anatomical Scans

**Things to check:**

1) **Good BET (Brain Extraction Tool) Segmentation**
   - Red outline (skullstrip) doesn’t include skull, outlines the brain  
   - Blue outline traces white matter area (lighter parts of brain)

2) **Good MNI wrap**
   - “Participant” brain only includes brain (no skull being included)  
   - Make sure that the brain isn’t being stretched down into the cerebellum (indicative of BET segmentation issue)

---

### Functional Scans

**Things to check:**

1) **Good EPI to T1 alignment**
   - The red/blue outlines should align with the functional image (darker/fuzzier image)  
   - Bright white parts of the functional image should be mostly excluded from the red/blue outline

2) **Good SDC correction**

   The “After” image should more closely align with the blue outline than the “Before” image.

3) **Clipping**

   In some cases the bottom part of the cerebellum gets clipped, this is acceptable (a pass) but should still be annotated as having a Clipping issue. However, if any part of the cortex itself is clipped (bottom or top) this rating should always result in a fail.

4) **EPI signal dropout**

   Large signal dropout in the EPI image but not in the T1, which should always result in a Fail.

---

## qsiprep

### Diffusion Section

1) **b=0 reference image**

   The brain mask creates a clear outline of the brain, with no significant deviations. Ensure to scroll through each of the sections, ensuring that the brain mask has correctly registered to the brain’s shape at each slice.

2) **DWI sampling Scheme**

   Compare the two images by rotating the images around and ensuring that they both generally make out the shape of a ball.

3) **b=0 to anatomical reference registration**

   This image represents the final output of the pipeline after motion correction, denoising, and bias field correction. It should be the first image checked for potential issues in earlier steps, such as excessive distortion, signal loss, or cropping. In a good-quality result, the image should clearly resemble brain anatomy with little to no visible artifacts outside the brain.

4) **DWI summary**

   In the FD plot, look for large or frequent spikes, which indicate sudden head movements during the scan. Consistently high FD values or many volumes above common thresholds (e.g., ~0.5 mm) suggest excessive motion and reduced data quality.

---

## ciftify

**Things to check:**

1) Make sure there is no black images, which happens if recon-all failed very early in the pipeline.

2) **Aparc image (examples of QC fails)**

   - Check the quality of image. For a very poor quality anatomical, the surface will look shrivelled up.
   - If the gray matter is missing part of the occipital lobe, the back of the brain will look split apart on the bottom view (far right).
   - For some participants, the surface reconstruction in the aparc view looks jagged (especially in the orbital frontal cortex).

3) **White and pial surfaces**

   A key place to look are the two temporal poles. Surface reconstruction in these areas can fail.
