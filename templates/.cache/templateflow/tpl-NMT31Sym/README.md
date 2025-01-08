# The NIMH Macaque Template v2 (NMT v2)

In depth information on the NMT v2 can be read in our paper:

	Jung, B., Taylor, P.A., Seidlitz, J., Sponheim, C., Perkins P.,
		Ungerleider, L.G., Glen, D., Messinger, A.
		A comprehensive macaque fMRI pipeline and hierarchical atlas.
		bioRxiv 2020.08.05.237818; doi: https://doi.org/10.1101/2020.08.05.237818

For any issues or questions, contact Adam Messinger at messinga@nih.gov

If you have any resources that you have made for the NMT v2 that you think would
be a useful addition, please send us an email and we'd be happy to integrate
them in the NMT v2 package.

## Description
The National Institute of Mental Health Macaque Template (NMT) v2 is a set of
anatomical MRI templates of the macaque brain that serves as a standardized
space for macaque neuroimaging analysis. It includes a fully-symmetric template
and an asymmetric themplate in stereotaxic orientation (i.e., with the
horizontal defined by the Horsley-Clarke plane) (Horsley and Clarke, 1908).
Coordinates in this stereotaxic space are measured from ear bar zero
(EBZ, i.e., the intersection of the midsagittal plane and a line through the
interaural meatus). The adoption of stereotaxic orientation and coordinates
will assist users in conducting surgical planning and reporting coordinates
commensurate with those used with other techniques (e.g. electrophysiology,
intracerebral injection).

Briefly, the NMT was created by iteratively nonlinearly registering the
T1-weighted MDEFT (Modified Driven Equilibrium Fourier Transform) scans of 31
adult rhesus macaque brains to a working template, averaging the nonlinearly
registered scans and then using the inverse transformations to bring the working
template closer to the group average (Seidlitz, Sponheim et al., 2018). The
symmetric NMT was generated through the same process except that each subject's
anatomical was input twice, once in its true orientation and once mirrored about
the midline. Modifications to the scan averaging and postprocessing have
improved template contrast and spatial resolution compared to the NMT v1.2.
Brainmasks, a 5-class tissue segmentation, and various other masks have been
provided with the NMT v2. We provide both symmetric and asymmetric variants of
the NMT v2 to allow users to choose the version best suited to their
analysis. The default NMT v2 is provided at 0.25 mm isotropic resolution, with a
field of view (FOV) that covers the entire brain and some surrounding CSF. We
additionally, provide a "full-head" version with an expanded FOV, to improve
alignment of scans with FOVs different than the NMT v2, and a "low-res" 0.5 mm
isotropic version for fast and efficient alignment. Surfaces for NMT v2,
generated using the new CIVET-Macaque platform (Lepage et al., submitted), are
provided to facilitate surface analysis and data visualization.


## Citation
If you use the NMT v2 or the CHARM in your work, please cite the paper below:

	Jung, B., Taylor, P.A., Seidlitz, J., Sponheim, C., Perkins P.,
		Ungerleider, L.G., Glen, D., Messinger, A.
		A comprehensive macaque fMRI pipeline and hierarchical atlas.
		bioRxiv 2020.08.05.237818; doi: https://doi.org/10.1101/2020.08.05.237818

Use of the SARM atlas should be accompanied with the following citation:

	Hartig, R., Glen, D., Jung, B., Logothetis, N.K., Paxinos G.,
		Garza-Villarreal, E.A., Messinger A., Evrard H.
		Subcortical Atlas of the Rhesus Macaque (SARM) for Magnetic Resonance Imaging
		bioRxiv 2020.09.16.300053; doi: https://doi.org/10.1101/2020.09.16.300053

Use of the D99 atlas (warped to the NMT v2 in this repository) should be
accompanied with the following citation:

	Reveley, C., Gruslys, A., Ye, F.Q., Glen, D., Samaha, J., E. Russ, B.,
		Saad, Z., K. Seth, A., Leopold, D.A., Saleem, K.S., 2017.
		Three-Dimensional Digital Template Atlas of the Macaque Brain.
		Cereb. Cortex N. Y. NY 27, 4463–4477. https://doi.org/10.1093/cercor/bhw248

## Atlases
We provide multiple anatomical atlases that have been manually refined to match
the morphology of the NMT v2: including the D99 atlas (Reveley et al., 2017) and
two new atlases specifically designed for the NMT v2: the CHARM and SARM atlases.

The Cortical Hierarchy Atlas of the Rhesus Macaque (CHARM; Jung et al.,
submitted) is a novel six-level anatomical parcellation of the macaque cerebral
cortex, where the cortical sheet is subdivided into finer and finer
parcellations at each successive level. The broadest level consists of the
four cortical lobes and the finest level is based on the D99 atlas with
modifications that make the regions more robust when applied to low resolution
(e.g. fMRI) data.

The Subcortical Atlas of the Rhesus Macaque (SARM; Hartig et al., submitted) was
designed based on updated regions originally defined in Paxinos et al. (2008).
These regions were drawn onto an ex-vivo MRI template and warped to the
symmetric NMT v2, where they were manually refined to correct for warping
inaccuracies. The atlas was then converted into a six-level hierarchy, in which
the original labels were combined into composite regions to form successively
larger structures.

Different scales of the CHARM or the SARM can be combined together so that,
for example, a tracer injection or the seed region for a resting state analysis
can be described using a fine scale while the anatomical or functional
connectivity can be succinctly described using a broader scale. In this way,
whole brain data can be characterized on a spatial scale that respects one’s
findings. Users can also use these hierarchies select a spatial scale a priori
based on how many regions it contains and thus what degree of multiple
comparison correction is required.

## Download

The NMT v2 is available directly from the [AFNI website](https://afni.nimh.nih.gov/NMT).
The asymmetric and symmetric NMT v2 templates are packaged in separate tar
files. Each tar file contains the standard NMT v2 template, as well as the
"full-head" and "low-res" variants, and the associated surfaces. These files are
provided in the standard NIFTI/GIFTI format, allowing them to be used with most
neuroimaging programs.

The @Install_NMT command is provided in AFNI to allow for downloading of the
NMT v2 with a single command.

To download the symmetric NMT v2, type the following into your terminal:
```bash
@Install_NMT -set_env -NMT_ver 2.0 -sym sym
```

To download the asymmetric NMT v2, type the following into your terminal:
```bash
@Install_NMT -set_env -NMT_ver 2.0 -sym asym
```

## NMT v2 Files

After downloading the NMT v2 and extracting its contents, you will see 7
directories:

  - Volumetric templates
	  - NMT_v2.0_[sym]/
	  - NMT_v2.0_[sym]_05mm/
	  - NMT_v2.0_[sym]_fh/
  - Surfaces
	  - NMT_v2.0_[sym]_surfaces/
  - Atlas Information
	  - tables_CHARM/
	  - tables_SARM/
	  - tables_D99/

where [sym] is either "sym" or "asym" depending on the selected template. The
contents of these directories are described in detail below.

### Volumetric Templates
There are 3 volumetric template directories, which all contain the NMT v2
template with associated masks and atlases.

  - NMT_v2.0_[sym]/ is the default NMT v2, with a limited FOV and 0.25 mm
	    isotropic resolution
  - NMT_v2.0_[sym]_05mm/ is the "low-res" NMT v2, with the same FOV and 0.50 mm
	    isotropic resolution
  - NMT_v2.0_[sym]_fh/ is the "full-head" NMT v2, with an expanded FOV and
	    0.25 mm isotropic resolution

Each directory will have the following files:

- **NMT_v2.0_[suf].nii.gz**                    : NMT v2 template
- **NMT_v2.0_[suf]_SS.nii.gz**                 : skullstripped template
- **NMT_v2.0_[suf]_brainmask.nii.gz**          : brain mask
- **NMT_v2.0_[suf]_segmentation.nii.gz**       : 5-class tissue segmentation
- **NMT_v2.0_[suf]_GM_cortical_mask.nii.gz**   : cortical sheet mask
- **CHARM_in_NMT_v2.0_[suf].nii.gz**           : A 4D volume of all 6 CHARM levels
- **supplemental_CHARM/**
	- **CHARM_1_in_NMT_v2.0_[suf].nii.gz** : Level 1 of the CHARM
	- **CHARM_2_in_NMT_v2.0_[suf].nii.gz** : Level 2 of the CHARM
	- **CHARM_3_in_NMT_v2.0_[suf].nii.gz** : Level 3 of the CHARM
	- **CHARM_4_in_NMT_v2.0_[suf].nii.gz** : Level 4 of the CHARM
	- **CHARM_5_in_NMT_v2.0_[suf].nii.gz** : Level 5 of the CHARM
	- **CHARM_6_in_NMT_v2.0_[suf].nii.gz** : Level 6 of the CHARM
- **SARM_in_NMT_v2.0_[suf].nii.gz**             : A 4D volume of all 6 SARM levels
- **supplemental_SARM/**
	- **SARM_1_in_NMT_v2.0_[suf].nii.gz**   : Level 1 of the SARM atlas
	- **SARM_2_in_NMT_v2.0_[suf].nii.gz**   : Level 2 of the SARM atlas
	- **SARM_3_in_NMT_v2.0_[suf].nii.gz**   : Level 3 of the SARM atlas
	- **SARM_4_in_NMT_v2.0_[suf].nii.gz**   : Level 4 of the SARM atlas
	- **SARM_5_in_NMT_v2.0_[suf].nii.gz**   : Level 5 of the SARM atlas
	- **SARM_6_in_NMT_v2.0_[suf].nii.gz**   : Level 6 of the SARM atlas
- **D99_atlas_in_NMT_v2.0_[suf].nii.gz**       : The D99 atlas mapped to the NMT
- **supplemental_masks/**
	- **NMT_v2.0_[suf]_LR_brainmask.nii.gz**     : Hemisphere-specific brain mask
	- **NMT_v2.0_[suf]_cerebellum_mask.nii.gz**  : Mask of the cerebellum
	- **NMT_v2.0_[suf]_ventricles.nii.gz**       : Mask of some of the ventricles

where [suf] describes the symmetry of the template ("sym" or "asym") and the
variant of the template ("_fh" for full-head or "_05mm" for low-res)

### Surfaces
We provide 3 surface types generated using the CIVET-macaque pipeline
(Lepage et al., submitted). These surface may be used to project data aligned to
any of the previously described volumetric surfaces:
- gray/pial surfaces
	- **lh.gray_surface.rsl.gii**
	- **rh.gray_surface.rsl.gii**
- mid-cortical surfaces
	- **lh.mid_surface.rsl.gii**
	- **rh.mid_surface.rsl.gii**
- white surfaces (white matter - gray matter boundary)
	- **lh.white_surface.rsl.gii**
	- **rh.white_surface.rsl.gii**
Additionally, semi-inflated versions of each of the above surfaces are provided.
These inflated surfaces may be useful for visualization of activity within sulci.

Surfaces of individual regions from the SARM and CHARM atlases are also provided.
These surfaces were generated using AFNI's IsoSurface command.

### Atlas Information
These directories contain information about the various atlases packaged with
the NMT v2. Each supplemental directory contains a label table, listing the
index, abbreviation and long-form name (when available) for each region in the
given atlas.

Additionally, we provide hierarchy tables for the CHARM and the SARM. These
CSV files show which ROIs are related hierarchically across the multiple levels
of these atlases.


## AFNI
While the NMT v2 works with any neuroimaging platform that accepts NIFTI/GIFTI
format, the NMT v2 templates and the CHARM have been designed to integrate
especially well into AFNI (Cox, 1996).

## Visualization in AFNI/SUMA

Opening and visualizing the NMT v2 is simple using AFNI and SUMA! This section
will use the full-head symmetric NMT v2 as an example, but these steps are
applicable to any version of the NMT v2.

Navigate to the directory where you have stored the NMT repository. Then follow
these steps:

```bash
cd NMT_v2.0_sym/NMT_v2.0_sym_fh/
afni -niml &
```

This will start AFNI and tell AFNI that a connection with SUMA is imminent. Load
in NMT_v2.0_sym_fh.nii.gz as the underlay if it is not loaded automatically.
Then, back in the terminal, run:

```bash
suma -spec ../NMT_v2.0_sym_surface/NMT_v2.0_sym_both.spec \
		 -sv NMT_v2.0_sym_fh.nii.gz &
```

This should start SUMA, and you should see the left and right WM surfaces. To
switch to a different set of surfaces, move your cursor into the SUMA window and
toggle the "." key. For other navigational shortcuts and tools, see the
[SUMA documentation](https://afni.nimh.nih.gov/pub/dist/doc/SUMA/suma/SUMA_do1.htm).

Toggle the "t" key to open the connection between AFNI and SUMA. You should see
various outlines on the NMT volume in AFNI that correspond with the surfaces
loaded into SUMA. To edit or remove the outlines in AFNI, toggle the
"Control Surface" button in the AFNI GUI.

Now that AFNI and SUMA are linked, this will allow you to visualize any data
(i.e. overlay) from the NMT volume on the surface. Note that only the voxels
which intersect the surface outlines will be plotted on the surface. As such,
we suggest using the "mid" surface for the visualization of any functional MRI
data. For more information about using AFNI interactively, see this
[slide show](https://afni.nimh.nih.gov/pub/dist/edu/latest/afni_handouts/afni03_interactive.pdf).

## MRI Alignment and fMRI Analysis
The NMT v2 is an important tool for group and ROI-based analyses. Aligning data
to the NMT v2 allows all of your data to be compared in a common space, and all
of your results to be reported in a reproducible and transparent manner. Here we
describe how AFNI and the NMT v2 can be used together for MRI alignment and fMRI
analysis. This is just a cursory explanation of processing macaque data in AFNI.
For a more complete picture, we have created downloadable demos showing
step-by-step how to perform structural and functional (both task-based and
resting state) analyses using AFNI and the NMT v2. These demos can be downloaded
using the AFNI commands @Install_MACAQUE_DEMO and @Install_MACAQUE_DEMO_REST.

Anatomical and functional MRI data can be easily and efficiently aligned to the
NMT v2 using AFNI. AFNI has an integrated command called @animal_warper that
allows for aligning animal (and specifically nonhuman primate) data to the NMT
v2. Affine and nonlinear alignments can be calculated with a single command, and
it additionally provides QC metrics and images that allow you to easily evaluate
the accuracy of your alignment. Additionally, @animal_warper can take atlases
and the segmentation from NMT v2 and warp them to native space, allowing for
ROI-based analyses in native space. Likewise, defined regions in native space
can be warped to the NMT v2 for group analyses.
The following is an example command using the NMT v2 with @animal_warper:

```bash
@animal_warper                                                  \
    -input  anat-sub-000.nii.gz                                 \
    -base   NMT_v2.0_sym_05mm/NMT_v2.0_sym_05mm.nii.gz          \
    -atlas  NMT_v2.0_sym_05mm/CHARM_in_NMT_v2.0_sym_05mm.nii.gz \
    -outdir AW_out_sub-000/                                     \
    -ok_to_exist
```

Warp files generated from @animal_warper can be directly used for fMRI analysis
in NMT v2 space. AFNI's processing pipeline generation program (afni_proc.py)
will take these warps and combine them with volume registration to prevent
repeated interpolation of fMRI data.

When afni_proc.py detects that data has been aligned to the NMT v2, it will
provide additional automated QC metrics by generating images of resting state
connectivity at defined seed locations in the NMT v2. These QC correlations maps
allow users to quickly compare their connectivity profiles across subjects, and
visually inspect their results for abnormalities (such as high correlations
between gray matter and white matter voxels).

For more information on @animal_warper and afni_proc.py, see the relevant
commands in AFNI, download the macaque analysis demos
(@Install_MACAQUE_DEMO and @Install_MACAQUE_DEMO_REST), or read our paper (Jung
et al., submitted)

### References
	Cox, R.W., 1996. AFNI: software for analysis and visualization of functional
		magnetic resonance neuroimages. Comput. Biomed. Res. Int. J. 29, 162–173.
		https://doi.org/10.1006/cbmr.1996.0014

	Hartig, R., Glen, D., Jung, B., Logothetis, N.K., Paxinos G.,
		Garza-Villarreal, E.A., Messinger A., Evrard H.
		Subcortical Atlas of the Rhesus Macaque (SARM) for Magnetic Resonance Imaging
		bioRxiv 2020.09.16.300053; doi: https://doi.org/10.1101/2020.09.16.300053

	Horsley, V., Clarke, R.H., 1908. THE STRUCTURE AND FUNCTIONS OF THE
		CEREBELLUM EXAMINED BY A NEW METHOD. Brain 31, 45–124.
		https://doi.org/10.1093/brain/31.1.45

	Lepage, C., Wagstyl, K., Jung, B., Seidlitz, J., Sponheim, C., Ungerleider,
		L., Wang, X., Evans, A.C., Messinger, A., submitted. CIVET-macaque: an
		automated pipeline for MRI-based cortical surface generation and cortical
		thickness in macaques. NeuroImage.

	Paxinos, G., Petrides, M., Huang, X.F., Toga, A.W., 2008. The Rhesus Monkey
		Brain in Stereotaxic Coordinates, 2 edition. ed. Academic Press, Amsterdam.

	Reveley, C., Gruslys, A., Ye, F.Q., Glen, D., Samaha, J., E. Russ, B.,
		Saad, Z., K. Seth, A., Leopold, D.A., Saleem, K.S., 2017. Three-Dimensional
		Digital Template Atlas of the Macaque Brain. Cereb. Cortex N. Y. NY 27,
		4463–4477. https://doi.org/10.1093/cercor/bhw248

	Seidlitz, J., Sponheim, C., Glen, D., Ye, F.Q., Saleem, K.S., Leopold, D.A.,
		Ungerleider, L., Messinger, A., 2018. A population MRI brain template and
		analysis tools for the macaque. NeuroImage, Segmenting the Brain 170, 121–131.
		https://doi.org/10.1016/j.neuroimage.2017.04.063
