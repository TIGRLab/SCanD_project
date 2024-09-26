#!/usr/bin/env python
"""
Take BIDS amico NODDI output and extracts from enigma DTI skeleton.

Usage:
  extract_NODDI_enigma.py [options] [arguments]

Arguments:
    --noddi_outputdir <dir>   Path to noddi outputs from qsiprep recon
    --enigma_outputdir <dir>  Path to enigma outputs (kimel version)
    --outputdir <dir>         Path for outputs
    --subject <string>        BIDS subject id
    --session <string>        BIDS session id

Options:
  -v,--verbose             Verbose logging
  --debug                  Debug logging in Erin's very verbose style
  -n,--dry-run             Dry run
  -h,--help                Print this help

DETAILS
Requires that both enigma DTI and AMICO NODDI has already been run
"""

from docopt import docopt
import pandas as pd
import nilearn.plotting
import glob
import os
import sys
import subprocess

DRYRUN = False
DEBUG = False

### Erin's little function for running things in the shell
def docmd(cmdlist):
    "sends a command (inputed as a list) to the shell"
    if DEBUG: 
        print(' '.join(cmdlist))
    if not DRYRUN: 
        subprocess.call(cmdlist)

##############################################################################

def fsl2std_noddi_output(NODDItag, noddi_dir, outputdir, subject, session):
    'convert the noddi output to enigma input with fslreorient2std'
    
    if session:
        image_i = os.path.join(noddi_dir, subject, session, "dwi", 
                                subject + "_" + session + "_space-T1w_desc-preproc_space-T1w_desc-" + NODDItag + "_NODDI.nii.gz")
        
        # Check if the first image path is empty or the file does not exist
        if not os.path.isfile(image_i):
            # Fallback to the second image path
            image_i = os.path.join(noddi_dir, subject, session, "dwi", 
                                    subject + "_" + session + "_acq-singleshelldir60b1000_run-1_space-T1w_desc-preproc_space-T1w_desc-" + NODDItag + "_NODDI.nii.gz")

        image_o = os.path.join(outputdir, subject + "_" + session, NODDItag, 'origdata', 
                               subject + "_" + session + "_space-T1w_desc-noddi_" + NODDItag + ".nii.gz")
        docmd(['mkdir', '-p', os.path.join(outputdir, 
                                             subject + "_" + session, NODDItag, 
                                             'origdata')])
    
    else:
        image_i = os.path.join(noddi_dir, subject, "dwi", 
                                subject + "_space-T1w_desc-preproc_space-T1w_desc-" + NODDItag + "_NODDI.nii.gz")

        # Check if the first image path is empty or the file does not exist
        if not os.path.isfile(image_i):
            # Fallback to the second image path
            image_i = os.path.join(noddi_dir, subject, "dwi", 
                                    subject + "_acq-singleshelldir60b1000_run-1_space-T1w_desc-preproc_space-T1w_desc-" + NODDItag + "_NODDI.nii.gz")

        image_o = os.path.join(outputdir, subject, NODDItag, 'origdata', 
                               subject + "_space-T1w_desc-noddi_" + NODDItag + ".nii.gz")
        docmd(['mkdir', '-p', os.path.join(outputdir, 
                                             subject, NODDItag, 
                                             'origdata')])
        
    # actually run the fslreorient2std bit
    docmd(['fslreorient2std', image_i, image_o])
    
## Now process the MD if that option was asked for
## if processing MD also set up for MD-ness
def run_non_FA(NODDItag, outputdir, enigmadir, subject, session):
    """
    The Pipeline to run to extract non-FA values (MD, AD or RD)
    """
     
    if session:
        O_dir = os.path.join(outputdir, 
                              '{}_{}'.format(subject, session))
        noddi_stem = subject + "_" + session + "_space-T1w_desc-noddi_"
        FA_dir = os.path.join(enigmadir, 
                               '{}_{}'.format(subject, session), 
                               "FA")
        FA_stem = "{}_{}_space-T1w_desc-preproc_fslstd_FA".format(subject, session)
    else:
        O_dir = os.path.join(outputdir, subject)
        noddi_stem = "{}_space-T1w_desc-noddi_".format(subject)
        FA_dir = os.path.join(enigmadir, 
                               subject, "FA")
        FA_stem = "{}_space-T1w_desc-preproc_fslstd_FA".format(subject)

    masked =    os.path.join(O_dir, NODDItag, 'origdata', noddi_stem + NODDItag + '.nii.gz')
    to_target = os.path.join(O_dir, NODDItag, 'origdata', noddi_stem + NODDItag + '_to_target.nii.gz')
    skel =      os.path.join(O_dir, NODDItag, 'origdata', noddi_stem + NODDItag + 'skel.nii.gz')
    skelqa =    os.path.join(O_dir, NODDItag, 'origdata', noddi_stem + NODDItag + 'skel.png')
    csvout1 =   os.path.join(O_dir, 'ROI', noddi_stem  + NODDItag + 'skel_ROIout')
    csvout2 =   os.path.join(O_dir, 'ROI', noddi_stem + NODDItag + 'skel_ROIout_avg')

    ## mask with subjects FA mask
    docmd(['fslmaths', 
           os.path.join(O_dir, NODDItag, 'origdata', 
                        noddi_stem + NODDItag + ".nii.gz"),
           '-mas', 
           os.path.join(FA_dir, FA_stem + '_mask.nii.gz'), 
           masked])

    # applywarp calculated for FA map
    docmd(['applywarp', '-i', masked, 
           '-o', to_target, 
           '-r', os.path.join(FA_dir, 'target'),
           '-w', os.path.join(FA_dir, FA_stem + '_to_target_warp.nii.gz')])

    ## tbss_skeleton step
    skel_thresh = 0.049
    docmd(['tbss_skeleton', 
           '-i', os.path.join(ENIGMAHOME, 'ENIGMA_DTI_FA.nii.gz'), 
           '-s', os.path.join(ENIGMAHOME, 'ENIGMA_DTI_FA_skeleton_mask.nii.gz'), 
           '-p', str(skel_thresh),
           os.path.join(ENIGMAHOME, 'ENIGMA_DTI_FA_skeleton_mask_dst.nii.gz'),
           os.path.join(FSLDIR, 'data', 'standard', 'LowerCingulum_1mm.nii.gz'),
           os.path.join(FA_dir, FA_stem + 'skel.nii.gz'),
           skel, 
           '-a', to_target])

    ## ROI extract
    docmd([os.path.join(ENIGMAHOME, 'singleSubjROI_exe'),
           os.path.join(ENIGMAHOME, 'ENIGMA_look_up_table.txt'), 
           os.path.join(ENIGMAHOME, 'ENIGMA_DTI_FA_skeleton.nii.gz'), 
           os.path.join(ENIGMAHOME, 'JHU-WhiteMatter-labels-1mm.nii.gz'), 
           csvout1, skel])

    ## ROI average
    docmd([os.path.join(ENIGMAHOME, 'averageSubjectTracts_exe'), 
           csvout1 + '.csv', csvout2 + '.csv'])

    if not DRYRUN:
        overlay_skel(skel_nii=skel, 
                     overlay_png_path=skelqa)

def overlay_skel(skel_nii, overlay_png_path, display_mode="z"):
    '''
    create an overlay image montage of
    skel_nii image in orange on top of the background_nii
    Uses nilearn plotting

    skel_nii        the nifty image to be overlayed in magenta (i.e. "FAskel.nii.gz")
    overlay_png_path     the name of the output (output.png)
    '''
    if display_mode == "x":
        cut_coords = [-36, -16, 2, 10, 42]
    if display_mode == "y":
        cut_coords = [-40, -20, -10, 0, 10, 20]
    if display_mode == "z":
        cut_coords = [-4, 2, 8, 12, 20]
    if display_mode == "3d":
        cut_coords = None

    # display the subject skel
    display = nilearn.plotting.plot_stat_map(skel_nii, 
        display_mode=display_mode, cut_coords=cut_coords, 
        title="Overlay NODDI skeleton", 
        threshold=0.05, colorbar=True, cmap='autumn')
    display.savefig(overlay_png_path)
    display.close()

##############################################################################

def main():
    args = docopt(__doc__)
    
    noddi_outputdir = args['--noddi_outputdir']
    enigma_outputdir = args['--enigma_outputdir']
    outputdir = args['--outputdir']
    subject = args['--subject']
    session = args['--session']
    global DRYRUN
    DRYRUN = args['--dry-run']
    global DEBUG
    DEBUG = args['--debug']

    # List of NODDI tags to process
    noddi_tags = ['MD', 'AD', 'RD']
    
    for NODDItag in noddi_tags:
        fsl2std_noddi_output(NODDItag, noddi_outputdir, outputdir, subject, session)
        run_non_FA(NODDItag, outputdir, enigma_outputdir, subject, session)

if __name__ == '__main__':
    main()
