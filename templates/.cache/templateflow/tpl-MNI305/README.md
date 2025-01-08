# MNI 305 Average Brain Stereotaxic Registration Model

This is a version of the MNI Average Brain (an average of 305 T1-weighted MRI scans, linearly transformed to Talairach space) specially adapted for use with the MNI Linear Registration Package (`mni_reg`).

## Methods

In order to overcome the idiosyncrasies of using a single subject brain as a template, in the early 1990s Evans and colleagues introduced the concept of a statistical MRI atlas for brain mapping (Evans et al., 1992a,b, 1993). The MNI305 atlas was constructed in two steps.

First, anatomical landmarks were manually identified in T1-weighted MRI scans from young healthy subjects. These landmarks were chosen from the Talairach and Tournoux atlas and thus the final aver- age and space approximated Talairach space. Landmarks from each subject were fitted together via least-squares linear regression that matched the resulting AC-PC line to the original Talairach and Tournoux atlas. This yielded a first-pass average T1-weighted MRI volume.

Second, each native MRI volume was automatically mapped to the manually-derived average MRI to reduce the impact of order effects, manual errors and to create a sharper average. The mapping was not performed according to Talairach’s piecewise linear model but used a whole-brain linear (9-parameter) image similarity residual (Collins et al., 1994). The resultant template is thus an approx- imation of the original Talairach space and the Z-coordinate is approximately +3.5 mm relative to the Talairach coordinate.

This process resulted in the original MNI305 atlas that has sub- sequently defined the MNI space. Note that, under constraints of linear alignment, residual non-linear anatomical variability across subjects gives rise to a “virtual convolution” (Evans et al., 1993) that somewhat enlarges the template compared with most individual brains.


This is a version of the MNI Average Brain (an average of 305
T1-weighted MRI scans, linearly transformed to Talairach space)
specially adapted for use with the MNI Linear Registration Package
(mni_reg).  Included in this package are the following files:

     average_305.mnc 
	a version of the average MRI that covers the whole brain
        (unlike the original Talairach atlas), sampled with 1mm cubic
        voxels
     average_305_mask.mnc 
	a mask of the brain in average_305.mnc, semi-automatically
        created by Dr. Colin Holmes <colin@pet.mni.mcgill.ca>.  Note
        that this mask has had holes filled in, so it is a connected
        volume but includes non-brain tissue (eg. the CSF in the
        ventricles)
     average_305_headmask.mnc 
	another mask, required for nonlinear mode

Here's a brief summary of what you need to do:

1) Build and install the entire MNI AutoReg package, as described in
   the README with that package. 

2) Install the model:
     * ./configure --prefix=/usr/local/mni
	     or where you installed mni_autoreg

     * make

     * make install

Now, you're ready to try out mritotal on real data.  See the file
TESTING included with MNI AutoReg for instructions on doing this.

Any problems with this package should be reported to 
Andrew Janke <a.janke@gmail.com>, or
Louis Collins <louis@bic.mni.mcgill.ca>.
