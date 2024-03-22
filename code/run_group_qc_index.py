#!/usr/bin/env python
"""
Create an index page of QC images from engima extract or enigma noddi

Usage:
  run_group_qc_index.py [options] <outputdir> <png_suffix>

Arguments:
    <outputdir>        Top directory for the output file structure
    <png_suffix>       Suffix to filter the images for (i.e. "FAskel")

Options:
  --subject-filter         String to filter subject list by
  -v,--verbose             Verbose logging
  --debug                  Debug logging in Erin's very verbose style
  -n,--dry-run             Dry run
  --help                   Print help

DETAILS
Writes an html page so that all qc images from a project can be viewed together.
Meant to be run after run_participant_enigma_extract.py or run_participant_noddi_enigma_extract.py

Written by Erin W Dickie, Sep 30, 2023
"""
from docopt import docopt
import os
import sys
from glob import glob


def main():

    global DEBUG
    global VERBOSE
    global DRYRUN

    arguments       = docopt(__doc__)
    outputdir       = arguments['<outputdir>']
    png_suffix      = arguments['<png_suffix>']
    subject_filter  = arguments['--subject-filter']
    VERBOSE         = arguments['--verbose']
    DEBUG           = arguments['--debug']
    DRYRUN          = arguments['--dry-run']

    if DEBUG: print(arguments)

    ## if no result file is given use the default name
    outputdir = os.path.normpath(outputdir)
    all_qa_imgs = sorted(glob('{}/*/*/*{}'.format(outputdir, png_suffix)))
    if len(all_qa_imgs) == 0:
        all_qa_imgs = sorted(glob('{}/*/*/*{}.png'.format(outputdir, png_suffix)))
    if len(all_qa_imgs) == 0:
        sys.exit("Could not find any images with extension {} in {}".format (png_suffix, outputdir))

    if subject_filter:
        index_qa_imgs = [x for x in all_qa_imgs if subject_filter in x]
    else:
        index_qa_imgs = all_qa_imgs

    # unpacking the tuple
    qa_stem, png_extension = os.path.splitext(png_suffix)

    ## write an html page that shows all the pics
    qchtml = open(os.path.join(outputdir, qa_stem + '_qc_index.html'),'w')
    qchtml.write('<HTML><TITLE>' + qa_stem + 'skeleton QC page</TITLE>')
    qchtml.write('<BODY BGCOLOR=#333333>\n')
    qchtml.write('<h1><font color="white">' + qa_stem + ' skeleton QC page</font></h1>')
    for pic in index_qa_imgs:
        relpath = os.path.relpath(pic, outputdir)
        qchtml.write('<a href="'+ relpath + '" style="color: #99CCFF" >')
        qchtml.write('<img src="' + relpath + '" "WIDTH=800" > ')
        qchtml.write(relpath + '</a><br>\n')
    qchtml.write('</BODY></HTML>\n')
    qchtml.close() # you can omit in most cases as the destructor will call it


if __name__ == '__main__':
    main()
