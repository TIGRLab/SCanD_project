#!/usr/bin/env python
"""NODDI Indices Extraction

Returns dictionary of NODDI amico fits for gray matter, white matter and CSF.

Usage:
    05-extract_NODDI_indices.py [options] <qsiprep_inpath> <amico_inpath> <noddi_outpath>

Arguments:
    <qsiprep_inpath>       Path of input QSIPrep, e.g. /KIMEL/tigrlab/scratch/jwong/datalad/qsiprep/
    <amico_inpath>         Path of input AMICO, e.g. /KIMEL/tigrlab/archive/data/TAY/pipelines/in_progress/jwong/dmri-microstructure/amico/qsirecon
    <noddi_outpath>        Output path, e.g. /KIMEL/tigrlab/scratch/jwong/test_NODDI_t1w_sample/

Options:
    -s --session=SESSION   Session number [default: ses-01]
    
Outputs the NODDI amico fits for gray matter, white matter and CSF, and create QC images.
"""

from docopt import docopt
import os
from glob import glob
from pathlib import Path
import nibabel as nib
import numpy as np
import pandas as pd
import nilearn
from nilearn import plotting


def image_meanval(img):
    'get mean value of nibabel image around removing zeros'
    data = img.get_fdata()
    data = data[data>0]
    result = data.mean()
    
    return(result)


def noddi_probseg_vals(subject, session, qsiprep_output_dir, qsiprep_amico_dir, out_dir):
    "returns dictionary of NODDI amico fits for gray matter, white matter and CSF"   
    scan_dict = {}
    scan_dict["subject_id"] = subject
    scan_dict["session"] = session
    
    for indice in ["ICVF", "ISOVF", "OD"]:
        for mask in ["CSF", "GM", "WM"]:

            #load the anatomical segmentation
            label_nii = Path(qsiprep_output_dir).joinpath(f"{subject}/anat/{subject}_label-{mask}_probseg.nii.gz")
            label_img = nib.load(str(label_nii))
            # load the NODDI image
            noddi_nii = Path(qsiprep_amico_dir).joinpath(f"{subject}/{session}/dwi/{subject}_{session}_space-T1w_desc-preproc_model-noddi_mdp-{indice}_dwimap.nii.gz")
            noddi_img = nib.load(str(noddi_nii))
            
            #make some QC images
            if indice not in ["ISOVF"]:
                if mask not in ["CSF"]:
                  for dsmode in ["x", "z"]:
                    plotting.plot_img(label_img, 
                                      bg_img = noddi_img,
                                      threshold = 0.93,
                                      display_mode = dsmode,
                                      title = f"{subject}_{session} {indice} {mask}",
                                      output_file = str(Path(f"{out_dir}/qc/{indice}_{mask}_{dsmode}/{subject}_{session}_{indice}_{mask}_{dsmode}.png")))  

            # mask the NODDI image with the anatomical mask and calculate the img mean
            label_resliced = nilearn.image.resample_to_img(source_img = label_img, target_img=noddi_img)
            masked_img = nilearn.image.math_img("img1*img2", img1 = label_resliced, img2 = noddi_img)
            scan_dict[f"{indice}_{mask}"] = image_meanval(masked_img)

    return scan_dict
            

def main():
    
    arguments = docopt(__doc__)
    qsiprep_output = arguments['<qsiprep_inpath>']
    qsiprep_amico = arguments['<amico_inpath>']
    out_dir = arguments['<noddi_outpath>']
    session = arguments['--session']

    ### Getting th list of subjects with both qsiprep and amico data
    rootdir = qsiprep_output
    qsiprep_subs = []
    for path in Path(rootdir).iterdir():
        if path.is_dir():
            qsiprep_subs.append(path.name)

    rootdir = qsiprep_amico
    noddi_subs = []
    for path in Path(rootdir).iterdir():
        if path.is_dir():
            noddi_subs.append(path.name)

    sublist = sorted(list(set(qsiprep_subs) & set(noddi_subs)))
    sublist = [i for i in sublist if i.startswith('sub-')]

    ### Create Output directory
    Path(f"{out_dir}/qc").mkdir(parents=True, exist_ok=True)

    for indice in ["ICVF", "OD"]:
        for mask in ["GM", "WM"]:
            for dsmode in ["x", "z"]:
                Path(f"{out_dir}/qc/{indice}_{mask}_{dsmode}").mkdir(exist_ok = True)

    ### Generate NODDI amico fits
    dict_list = []

    for subject in sublist:
        sub_dict = noddi_probseg_vals(subject, session, qsiprep_output, qsiprep_amico, out_dir)
        dict_list.append(sub_dict)

    noddi_df = pd.DataFrame.from_dict(dict_list)


    ### Save output CSV
    noddi_df.to_csv(Path(f"{out_dir}/group_noddi_byprobseg.csv"))


if __name__ == '__main__':
    main()
