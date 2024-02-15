#!/usr/bin/env python
"""
Run QC -stuff for dtifit outputs.

Usage:
  run_group_dtifit.py [options] <dtifitdir>

Arguments:
    <dtifitdir>        Top directory for the output file structure

Options:
  --QCdir <path>           Full path to location of QC outputs (defalt: <outputdir>/QC')
  --tag <tag>              Only QC files with this string in their filename (ex.'DTI60')
  --subject <subid>        Only process the subjects given (good for debugging, default is to do all subs in folder)
  -v,--verbose             Verbose logging
  --debug                  Debug logging in Erin's very verbose style
  -n,--dry-run             Dry run
  --help                   Print help

DETAILS
This creates some QC outputs from of ditfit pipeline stuff.
QC outputs are placed within <outputdir>/QC unless specified otherwise ("--QCdir <path").
Right now QC constist of pictures for every subject.
Pictures are assembled in html pages for quick viewing.

The inspiration for these QC practices come from engigma DTI
http://enigma.ini.usc.edu/wp-content/uploads/DTI_Protocols/ENIGMA_FA_Skel_QC_protocol_USC.pdf

Future plan: add section that checks results for normality and identifies outliers..

Requires datman python enviroment, FSL and imagemagick.

Written by Erin W Dickie, August 25 2015
"""
from docopt import docopt
import os
import nilearn.plotting
import tempfile
import shutil
import glob
import subprocess
import sys

convert_directory = '/usr/bin/'

### Erin's little function for running things in the shell
def docmd(cmdlist):
    "sends a command (inputed as a list) to the shell"
    if DEBUG: print(' '.join(cmdlist))
    if not DRYRUN:
        # Modify the PATH environment variable to include the directory
        env = os.environ.copy()
        env['PATH'] = convert_directory + os.pathsep + env.get('PATH', '')
        subprocess.call(cmdlist, env=env)


def main():

    global DEBUG
    global DRYRUN

    arguments       = docopt(__doc__)
    dtifitdir       = arguments['<dtifitdir>']
    QCdir           = arguments['--QCdir']
    TAG             = arguments['--tag']
    SUBID           = arguments['--subject']
    VERBOSE         = arguments['--verbose']
    DEBUG           = arguments['--debug']
    DRYRUN          = arguments['--dry-run']

    if DEBUG: print(arguments)
    if QCdir == None: QCdir = os.path.join(dtifitdir,'QC')

    ## check that FSL has been loaded - if not exists
    FSLDIR = os.getenv('FSLDIR')
    if FSLDIR==None:
        sys.exit("FSLDIR environment variable is undefined. Try again.")


    ## find the files that match the resutls tag...first using the place it should be from doInd-enigma-dti.py
    ## find those subjects in input who have not been processed yet and append to checklist
    ## glob the dtifitdir for FA files to get strings
    allFAmaps1 = glob.glob(dtifitdir + '/sub*/ses*/dwi/*FA.nii.gz*')
    allFAmaps2 = glob.glob(dtifitdir + '/sub*/dwi/*FA.nii.gz*')
    allFAmaps = allFAmaps1 + allFAmaps2
    allFAmaps.sort()

    if SUBID != None:
        allFAmaps = [ v for v in allFAmaps if SUBID in v ]

    if DEBUG : print("FAmaps before filtering: {}".format(allFAmaps))

    # if filering tag is given...filter for it
    if TAG != None:
        allFAmaps = [ v for v in allFAmaps if TAG in v ]
    if DEBUG : print("FAmaps after filtering: {}".format(allFAmaps))
    allFAmaps = [ v for v in allFAmaps if "PHA" not in v ] ## remove the phantoms from the list

    #mkdir a tmpdir for the
    tmpdirbase = tempfile.mkdtemp()
    # tmpdirbase = os.path.join(QCdir,'tmp')
    # dm.utils.makedirs(tmpdirbase)

    # make the output directories
    # QC_bet_dir = os.path.join(QCdir,'BET')
    QC_V1_dir = os.path.join(QCdir, 'directions')
    # os.makedirs(QC_bet_dir)
    os.makedirs(QC_V1_dir, exist_ok = True)

    QC_sse_dir = os.path.join(QCdir, 'error')
    os.makedirs(QC_sse_dir, exist_ok = True)

    #maskpics = []
    ssepics = []
    V1pics = []
    for FAmap in allFAmaps:
        ## manipulate the full path to the FA map to get the other stuff
        # suffix = '_desc-dtifit_FA.nii.gz'
        suffix = '_desc-preproc_fslstd_FA.nii.gz'
        basename = os.path.basename(FAmap).replace(suffix,'')
        pathbase = FAmap.replace(suffix,'')
        tmpdir = os.path.join(tmpdirbase,basename)
        os.makedirs(tmpdir)

        # maskpic = os.path.join(QC_bet_dir,basename + 'b0_bet_mask.gif')
        # maskpics.append(maskpic)
        # if os.path.exists(maskpic) == False:
        #     mask_overlay(pathbase + 'b0.nii.gz',pathbase + 'b0_bet_mask.nii.gz', maskpic)

        sse_suffix = '_desc-preproc_fslstd_sse.nii.gz'
        ssepic = os.path.join(QC_sse_dir,basename + '_sse.png')
        ssepics.append(ssepic)
        if os.path.exists(ssepic) == False:
            #mask_overlay(pathbase + '_desc-dtifit_sse.nii.gz',"", ssepic, tmpdir)
            sse_plots(pathbase + sse_suffix, ssepic, display_mode = "y")

        v1_suffix = '_desc-preproc_fslstd_V1.nii.gz'
        V1pic = os.path.join(QC_V1_dir,basename + 'dtifit_V1.gif')
        V1pics.append(V1pic)
        if os.path.exists(V1pic) == False:
            V1_overlay(FAmap,pathbase + v1_suffix, V1pic, tmpdir)


    ## write an html page that shows all the BET mask pics
    # qchtml = open(os.path.join(QCdir,'qc_BET.html'),'w')
    # qchtml.write('<HTML><TITLE>DTIFIT BET QC page</TITLE>')
    # qchtml.write('<BODY BGCOLOR=#333333>\n')
    # qchtml.write('<h1><font color="white">DTIFIT BET QC page</font></h1>')
    # for pic in maskpics:
    #     relpath = os.path.relpath(pic,QCdir)
    #     qchtml.write('<a href="'+ relpath + '" style="color: #99CCFF" >')
    #     qchtml.write('<img src="' + relpath + '" "WIDTH=800" > ')
    #     qchtml.write(relpath + '</a><br>\n')
    # qchtml.write('</BODY></HTML>\n')
    # qchtml.close() # you can omit in most cases as the destructor will call it

    ## write an html page that shows all the BET mask pics
    qchtml = open(os.path.join(QCdir,'qc_sse.html'),'w')
    qchtml.write('<HTML><TITLE>DTIFIT Error QC page</TITLE>')
    qchtml.write('<BODY BGCOLOR=#333333>\n')
    qchtml.write('<h1><font color="white">DTIFIT Error QC page</font></h1>')
    for pic in ssepics:
        relpath = os.path.relpath(pic,QCdir)
        qchtml.write('<a href="'+ relpath + '" style="color: #99CCFF" >')
        qchtml.write('<img src="' + relpath + '" "WIDTH=800" > ')
        qchtml.write(relpath + '</a><br>\n')
    qchtml.write('</BODY></HTML>\n')
    qchtml.close() # you can omit in most cases as the destructor will call it

    ## write an html page that shows all the V1 pics
    qchtml = open(os.path.join(QCdir,'qc_directions.html'),'w')
    qchtml.write('<HTML><TITLE>DTIFIT directions QC page</TITLE>')
    qchtml.write('<BODY BGCOLOR=#333333>\n')
    qchtml.write('<h1><font color="white">DTIFIT directions QC page</font></h1>')
    for pic in V1pics:
        relpath = os.path.relpath(pic,QCdir)
        qchtml.write('<a href="'+ relpath + '" style="color: #99CCFF" >')
        qchtml.write('<img src="' + relpath + '" "WIDTH=800" > ')
        qchtml.write(relpath + '</a><br>\n')
    qchtml.write('</BODY></HTML>\n')
    qchtml.close() # you can omit in most cases as the destructor will call it


    #get rid of the tmpdir
    shutil.rmtree(tmpdirbase)

def gif_gridtoline(input_gif, output_gif, tmpdir):
    '''
    uses imagemagick to take a grid from fsl slices and convert to one line (like in slicesdir)
    '''
    docmd([os.path.join(convert_directory, 'convert'), input_gif, '-resize', '384x384', input_gif])
    docmd([os.path.join(convert_directory, 'convert'), input_gif,\
        '-crop', '100x33%+0+0', os.path.join(tmpdir, 'sag.gif')])
    docmd([os.path.join(convert_directory, 'convert'), input_gif,\
        '-crop', '100x33%+0+128', os.path.join(tmpdir, 'cor.gif')])
    docmd([os.path.join(convert_directory, 'convert'), input_gif,\
        '-crop', '100x33%+0+256', os.path.join(tmpdir, 'ax.gif')])
    docmd([os.path.join(convert_directory, 'montage'), '-mode', 'concatenate', '-tile', '3x1', \
        os.path.join(tmpdir, 'sag.gif'),\
        os.path.join(tmpdir, 'cor.gif'),\
        os.path.join(tmpdir, 'ax.gif'),\
        output_gif])
  
def mask_overlay(background_nii,mask_nii, overlay_gif, tmpdir):
    '''
    use slices from fsl to overlay the mask on the background (both nii)
    then make the grid to a line for easier scrolling during QC
    '''
    docmd(['slices', background_nii, mask_nii, '-o', os.path.join(tmpdir,'BOmasked.gif')])
    gif_gridtoline(os.path.join(tmpdir,'BOmasked.gif'),overlay_gif, tmpdir)

def sse_plots(sse_nii, png_out, display_mode = "z"):
    '''
    use nilearn plotting to make an image of the dtifit errors
    '''

    if display_mode=="x":
        cut_coords = [-36, -16, 2, 10, 42]
    if display_mode=="y":
        cut_coords = [-40, -20, -10, 0, 10, 20]
    if display_mode=="z":
        cut_coords = [-4, 2, 8, 12, 20, 40]

    nilearn.plotting.plot_img(sse_nii,
       colorbar = True,
       display_mode = display_mode,
       cut_coords = cut_coords,
       vmin = 0, vmax = 50,
       output_file = png_out)

def V1_overlay(background_nii,V1_nii, overlay_gif, tmpdir):
    '''
    use fslsplit to split the V1 image and take pictures of each direction
    use slices from fsl to get the background and V1 picks (both nii)
    recolor the V1 image using imagemagick
    then make the grid to a line for easier scrolling during QC
    '''
    docmd(['slices',background_nii,'-o',os.path.join(tmpdir,"background.gif")])
    docmd(['fslmaths',background_nii,'-thr','0.15','-bin',os.path.join(tmpdir,'FAmask.nii.gz')])
    docmd(['fslsplit', V1_nii, os.path.join(tmpdir,"V1")])
    for axis in ['0000','0001','0002']:
        docmd(['fslmaths',os.path.join(tmpdir,'V1'+axis+'.nii.gz'), '-abs', \
            '-mul', os.path.join(tmpdir,'FAmask.nii.gz'), os.path.join(tmpdir,'V1'+axis+'abs.nii.gz')])
        docmd(['slices',os.path.join(tmpdir,'V1'+axis+'abs.nii.gz'),'-o',os.path.join(tmpdir,'V1'+axis+'abs.gif')])
        # docmd(['convert', os.path.join(tmpdir,'V1'+axis+'abs.gif'),\
        #         '-fuzz', '15%', '-transparent', 'black', os.path.join(tmpdir,'V1'+axis+'set.gif')])
    docmd([os.path.join(convert_directory, 'convert'), os.path.join(tmpdir,'V10000abs.gif'),\
        os.path.join(tmpdir,'V10001abs.gif'), os.path.join(tmpdir,'V10002abs.gif'),\
        '-set', 'colorspace', 'RGB', '-combine', '-set', 'colorspace', 'sRGB',\
        os.path.join(tmpdir,'dirmap.gif')])
    gif_gridtoline(os.path.join(tmpdir,'dirmap.gif'),overlay_gif, tmpdir)

if __name__ == '__main__':
    main()
