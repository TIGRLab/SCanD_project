# Colin 27 Average Brain, Stereotaxic Registration Model

## Overview
This is a stereotaxic average of 27 T1-weighted MRI scans of the same individual.

In 1998, a new atlas with much higher definition than MNI305s was created at the MNI. One individual (CJH) was scanned 27 times and the images linearly registered to create an average with high SNR and structure definition (Holmes et al., 1998). This average was linearly registered to the average 305. Ironically, this dataset was not originally intended for use as a stereotaxic template but as the sub- strate for an ROI parcellation scheme to be used with ANIMAL non-linear spatial normalization (Collins et al., 1995), i.e. it was intended for the purpose of segmentation, NOT stereotaxy. As a single brain atlas, it did not capture anatomical variability and was, to some degree, a reversion to the Talairach approach.

However, the high definition proved too attractive to the community and, after non-linear mapping to fit the MNI305 space, it has been adopted by many groups as a stereotaxic template (e.g., AFNI, Cox,; Brainstorm, Tadel et al., 2011; SPM, Litvak et al., 2011; Fieldtrip, Oostenveld et al., 2011).

## Methods

This average dataset was created in a two step process. First, each of the 27 T1-weighted scans were registered to stereotaxic space using the mritotal procedure and resampled onto a 1mm grid in stereotaxic space. All 27 scans were averaged together to create an initial average. This average volume was used as a target for the second phase of registration where each original T1-weighted MRI was re-registered in stereotaxic space. This procedure has the advantage of removing the small variance in intra-subject mapping in stereotaxic space associated with the use of a multi-subject average.

## Publications

* Holmes CJ, Hoge R, Collins L, Woods R, Toga AW, Evans AC. “Enhancement of MR images using registration for signal averaging.” J Comput Assist Tomogr. 1998 Mar-Apr;22(2):324–33. https://doi.org/10.1097/00004728-199803000-00032

## License

Copyright (C) 1993–2009 Louis Collins, McConnell Brain Imaging Centre, Montreal Neurological Institute, McGill University. Permission to use, copy, modify, and distribute this software and its documentation for any purpose and without fee is hereby granted, provided that the above copyright notice appear in all copies. The authors and McGill University make no representations about the suitability of this software for any purpose. It is provided “as is” without express or implied warranty. The authors are not responsible for any data loss, equipment damage, property loss, or injury to subjects or patients resulting from the use or misuse of this software package.

