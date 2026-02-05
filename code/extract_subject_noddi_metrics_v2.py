#!/usr/bin/env python3
"""
Extracts NODDI metrics for dseg files in subject folder

Usage:
    extract_subject_noddi_metrics [options] --subject <subject> --parc-dir <parc-dir> --qsiprep-dir <qsiprep-dir> --amico-noddi-dir <amico-noddi>

Arguments:
    --subject <subject>              BIDS subject id
    --parc-dir <parc-dir>            Input and output directory
    --qsiprep-dir <qsiprep-dir>      Input qsiprep output directory
    --amico-noddi-dir <amico-noddi>  Input amico-noddi outputs from qsiprep
Options:
    --session <session>      BIDS session to pull the amico noddi values from
    --icvf-thresh <thres>    Threshold [default: 0.99] used for creating brainmask
    --parcellation <parc>   List of parcellations to pull data from (defaults to all)

    --debug                Debug logging
    -h, --help             Prints this message

DETAILS:

Part of Erin workflow for extracting from QSIPREP AMINO NODDI outputs

the parcellations dir (parc dir) serves are both input (for parcelations) and output directory

the icvf threshold will create a brainmask where icvf values are between zero and that threshold. It is used to remove values of 1 from the mean calculations. (favouring GM values over CSF values)

"""


from docopt import docopt

import os.path
from glob import glob

import pandas as pd
import numpy as np
import seaborn as sns

import nilearn.plotting
from nilearn.image import index_img, math_img, resample_to_img
from nilearn.maskers import NiftiLabelsMasker
from bids.layout import parse_file_entities

import logging
logger = logging.getLogger(os.path.basename(__file__))


## filename helpers
def noddi_filename(noddi_dir, subject, session, noddi_mdp):
    """
    Find the NODDI filename for a given subject/session/metric using a flexible pattern. v2 HA
        assuming qsioutput
    """
    if session:
        pattern = f"{noddi_dir}/sub-{subject}/ses-{session}/dwi/sub-{subject}_ses-{session}_*space-T1w*_model-noddi_*-{noddi_mdp}_dwimap.nii*" ## adjust the flag to capture the file names (amico or custom noddi, this should work for both)
    else:
        pattern = f"{noddi_dir}/sub-{subject}/dwi/sub-{subject}_*space-T1w*_model-noddi_*-{noddi_mdp}_dwimap.nii*"

    matches = glob(pattern)
    if len(matches) == 0:
        raise FileNotFoundError(f"NODDI file not found with pattern: {pattern}")
    return matches[0]


## the big one that makes the big tsv
def extract_noddi_parc_results(
    subject,
    session,
    parc_file,
    parc_tsv,
    noddi_dir,
    qsiprep_dir,
    tsv_out=None,
    icvf_max_threshold=0.99,
    strict_labels=False,          # if True: raise on missing label TSV
    autogen_labels=False          # if True: create ROI_<index> labels when TSV missing
):
    """
    Extract parcel-wise NODDI stats (mean/stdev) + tissue probabilities from a labels image.

    strict_labels:
        - True  -> missing parc_tsv raises FileNotFoundError
        - False -> missing parc_tsv will skip labels (or autogen if autogen_labels=True)
    autogen_labels:
        - If parc_tsv is missing, create label table with name=ROI_<index> for each parcel.
    """
    # Load parcellation image
    parc_img = nilearn.image.load_img(parc_file)

    # voxel volume (mm^3): pixdim[1], [2], [3]
    pixdim = parc_img.header.get_zooms()[:3]  # (x, y, z)
    voxel_size = float(pixdim[0] * pixdim[1] * pixdim[2])

    # Unique labels + voxel counts
    data = parc_img.get_fdata()
    labels, counts = np.unique(data.astype(np.int32), return_counts=True)

    results = pd.DataFrame({"index": labels, "n_vx_full": counts})
    # filter out background label 0 (filter by *label value*, not dataframe row index)
    results = results[results["index"] > 0].copy()
    results["size_full"] = results["n_vx_full"] * voxel_size

    # ---- label names (TSV) ----
    if parc_tsv and os.path.exists(parc_tsv):
        labeldf = pd.read_csv(parc_tsv, sep="\t")
        # tolerate extra columns, require at least index+name
        if not {"index", "name"}.issubset(labeldf.columns):
            raise ValueError(f"Label TSV missing required columns {{index,name}}: {parc_tsv}")

        labeldf = labeldf[["index", "name"]].copy()
        labeldf["index"] = labeldf["index"].astype(int)
        labeldf = labeldf.drop_duplicates("index").set_index("index")

        results = results.set_index("index")
        results = results.join(labeldf, how="left")
        results = results.reset_index()

    else:
        if strict_labels:
            raise FileNotFoundError(f"Parcellation label TSV not found: {parc_tsv}")
        if autogen_labels:
            results["name"] = results["index"].apply(lambda x: f"ROI_{int(x)}")
        else:
            results["name"] = np.nan  # keep column present for downstream consistency

    # We'll define good_parc_img once (masked version for icvf threshold)
    good_parc_img = parc_img

    # ---- NODDI metrics ----
    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)

        if noddi_mdp == "icvf":
            if icvf_max_threshold is not None:
                # Mask out icvf==1 (and zeros) to avoid CSF / invalid voxels
                good_dwi = math_img(
                    f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})",
                    img1=noddi_file
                )
                good_parc_img = math_img("img1 * img2", img1=good_dwi, img2=parc_img)
            else:
                good_parc_img = parc_img

            # recompute masked voxel counts per parcel for coverage
            gdata = good_parc_img.get_fdata().astype(np.int32)
            glabels, gcounts = np.unique(gdata, return_counts=True)
            masked_df = pd.DataFrame({"index": glabels, "n_vx_masked": gcounts})
            masked_df = masked_df[masked_df["index"] > 0]

            results = results.merge(masked_df, on="index", how="left")
            results["n_vx_masked"] = results["n_vx_masked"].fillna(0).astype(int)
            results["coverage"] = np.where(
                results["n_vx_full"] > 0,
                results["n_vx_masked"] / results["n_vx_full"],
                np.nan
            )

        # Mean
        masker_mean = NiftiLabelsMasker(labels_img=good_parc_img, strategy="mean")
        mean_vals = masker_mean.fit_transform(noddi_file).ravel()
        vals = np.full(len(results), np.nan)
        vals[:len(mean_vals)] = mean_vals
        results[f"{noddi_mdp}_mean"] = vals


        # Std
        masker_std = NiftiLabelsMasker(labels_img=good_parc_img, strategy="standard_deviation")
        std_vals = masker_std.fit_transform(noddi_file).ravel()
        vals = np.full(len(results), np.nan)
        vals[:len(std_vals)] = std_vals
        results[f"{noddi_mdp}_stdev"] = vals


    # ---- Tissue probability (GM/WM/CSF) from qsiprep dseg ----
    qsiprep_dseg = os.path.join(qsiprep_dir, f"sub-{subject}", "anat", f"sub-{subject}_dseg.nii.gz")
    if os.path.exists(qsiprep_dseg):
        tissue_img = resample_to_img(qsiprep_dseg, good_parc_img, interpolation="nearest")

        dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}
        for tissue, value in dseg_labels.items():
            tissue_mask = math_img(f"img1 == {int(value)}", img1=tissue_img)
            tmasker = NiftiLabelsMasker(labels_img=good_parc_img, strategy="mean")
            tvals = tmasker.fit_transform(tissue_mask).ravel()
            vals = np.full(len(results), np.nan)
            vals[:len(tvals)] = tvals
            results[f"{tissue}_prob"] = vals

        results["tissue"] = results[["CSF_prob", "GM_prob", "WM_prob"]].idxmax(axis=1).str.replace("_prob", "")
        results["tissue_prob"] = results[["CSF_prob", "GM_prob", "WM_prob"]].max(axis=1)
    else:
        # keep columns for schema consistency
        for tissue in ["CSF", "GM", "WM"]:
            results[f"{tissue}_prob"] = np.nan
        results["tissue"] = np.nan
        results["tissue_prob"] = np.nan

    # Add subject/session columns and final column order
    results["subject"] = subject
    results["session"] = session

    outcols = [
        "subject", "session", "index", "name",
        "tissue", "tissue_prob",
        "size_full", "n_vx_full", "n_vx_masked", "coverage",
        "od_mean", "od_stdev",
        "icvf_mean", "icvf_stdev",
        "isovf_mean", "isovf_stdev",
    ]

    # Ensure missing cols exist (in case strict_labels False etc.)
    for c in outcols:
        if c not in results.columns:
            results[c] = np.nan

    results = results[outcols]

    if tsv_out:
        os.makedirs(os.path.dirname(tsv_out), exist_ok=True)
        results.to_csv(tsv_out, index=False, sep="\t")

    return results


def make_noddi_3tissues_plot(subject, session, noddi_dir, qsiprep_dir, out_png = None, icvf_max_threshold = 0.99):
    ''' make density plots by dseg tissue types'''

    qsiprep_dseg=os.path.join(f'{qsiprep_dir}/sub-{subject}/anat/sub-{subject}_dseg.nii.gz')
    dseg_labels =  {"CSF":1, "GM":2, "WM":3}

    df0 = pd.DataFrame(columns = ['tissue', 'value', 'noddi'])

    for noddi_mdp in ["icvf", "od", "isovf"]:

        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)

        if noddi_mdp=="icvf":
            tissue_img = resample_to_img(qsiprep_dseg, noddi_file, interpolation = 'nearest')
            good_dwi = math_img(f"(img1 > 0) * (img1 < {icvf_max_threshold})", img1 = noddi_file)
            good_tissue_img = math_img('img1*img2', img1 = good_dwi, img2 = tissue_img)

        for tissue,value in dseg_labels.items():
            noddi_tissue = math_img(f'(img1 == {value})*img2', img1=good_tissue_img, img2=noddi_file)
            noddi_flat = noddi_tissue.get_fdata().flatten()
            noddi_flat = noddi_flat[noddi_flat > 0]
            df1 = pd.DataFrame({'tissue': tissue, 'noddi': noddi_mdp, 'value':noddi_flat})
            df0 = pd.concat([df0, df1], axis=0)

    plt = sns.FacetGrid(df0, col="noddi", hue = 'tissue')
    plt.map_dataframe(sns.kdeplot,x = "value", clip = [0, 1])
    plt.add_legend()
    plt.fig.subplots_adjust(top=0.9) # adjust the Figure in rp
    plt.fig.suptitle(f'sub-{subject} ses-{session} NODDI values by tisse)',
                     verticalalignment = 'bottom')

    if out_png:
        plt.savefig(out_png)

    return(plt)



def make_dseg_qsi_qa_image(subject, session, noddi_mdp, noddi_dir, parc_file, parc_name, out_png):
    ''' output a qa of parcellation on top of noddi map'''

    noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)

    plt = nilearn.plotting.plot_roi(roi_img = parc_file, bg_img = noddi_file,
                              alpha = 0.4,
                              display_mode = "mosaic",
                             title = '{} {} on noddi {}'.format(subject, parc_name, noddi_mdp),
                             output_file = out_png)
    return plt



def main():
    arguments = docopt(__doc__)

    logger.setLevel(logging.WARNING)

    if arguments['--debug']:
        logger.setLevel(logging.DEBUG)

    logger.info(arguments)

    parc_dir = arguments['--parc-dir']

    qsiprep_dir = arguments['--qsiprep-dir']
    noddi_dir = arguments['--amico-noddi-dir']

    subject=arguments['--subject']
    subject = str(subject).replace('sub-','')

    session=arguments['--session']
    icvf_max_threshold = arguments['--icvf-thresh']

    templates_dir = parc_dir

    parc_list = arguments['--parcellation']

    if not parc_list:
        parc_list = []
        parc_files = glob(f'{parc_dir}/sub-{subject}/anat/sub-{subject}_space-ACPC_desc-*_dseg.nii.gz')

        if len(parc_files) > 0:
            for parc_file in parc_files:
                parc = parse_file_entities(parc_file)['desc']
                parc_list.append(parc)
        else:
            logger.error(f'No ACPC parcellations found in {parc_dir}/sub-{subject}/anat')

    else:
        parc = parc_list
        parc_file = os.path.join(f'{parc_dir}/sub-{subject}/anat/sub-{subject}_space-ACPC_desc-{parc}_dseg.nii.gz')
        if not os.path.exists(parc_file):
            logger.error(f"Input parcellation file {parc_file} not found")


    if session:
        session = str(session).replace('ses-','')
        sessions = [session]
        noddi_file = noddi_filename(noddi_dir, subject, session, 'icvf')
        if not os.path.exists(noddi_file):
            logger.error(f'Input {noddi_file} not found')
    else:
        blist = glob(f"{noddi_dir}/sub-{subject}/*/dwi/*model-noddi_mdp-icvf*")
        b2 = glob(f"{noddi_dir}/sub-{subject}/dwi/*model-noddi_mdp-icvf*")
        blist.extend(b2)
        if len(blist)>0:
            ses_list = []
            for bfile in blist:
                ses = parse_file_entities(bfile)['session']
                ses_list.append(ses)
            sessions = list(set(ses_list))
            if len(sessions) < 1: sessions = ['None']
        else:
            logger.error(f"No input noddi files found in {noddi_dir}/sub-{subject}")


    ## first make a density plot across tissues
    for session in sessions:

        if session:
            noddi_3tissue_out = os.path.join(f'{parc_dir}/sub-{subject}/figures/sub-{subject}_ses-{session}_desc-dsegtissue_model-noddi_density.png')
        else:
            noddi_3tissue_out = os.path.join(f'{parc_dir}/sub-{subject}/figures/sub-{subject}_desc-dsegtissue_model-noddi_density.png')

        if not os.path.exists(os.path.dirname(noddi_3tissue_out)):
                os.makedirs(os.path.dirname(noddi_3tissue_out))

        make_noddi_3tissues_plot(subject=subject,
                                session=session,
                                noddi_dir=noddi_dir,
                                qsiprep_dir=qsiprep_dir,
                                out_png = noddi_3tissue_out,
                                icvf_max_threshold = icvf_max_threshold)

        ## now loop over the parcellations
        for parc in parc_list:
            parc_file=os.path.join(f'{parc_dir}/sub-{subject}/anat/sub-{subject}_space-ACPC_desc-{parc}_dseg.nii.gz')

            ## make a two qa figures plotted on OD and ICVF
            for noddi_mdp in ["od", "icvf"]:
                if session:
                    out_png = os.path.join(f'{parc_dir}/sub-{subject}/figures/sub-{subject}_ses-{session}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png')

                else:
                    out_png = os.path.join(f'{parc_dir}/sub-{subject}/figures/sub-{subject}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png')

                make_dseg_qsi_qa_image(subject = subject,
                                    session = session,
                                    noddi_mdp = noddi_mdp,
                                    noddi_dir = noddi_dir,
                                    parc_file = parc_file,
                                    parc_name = parc,
                                    out_png = out_png)

            ## then extract a table with a bunch of things
            ## if it's a freesurfer parcellation - then labels come from freesurfer label table
            if parc in ['wmparc', 'aparcaseg']:
                parc_tsv=os.path.join(f'{templates_dir}/desc-FreeSurferAll_dseg.tsv')
            else:
                parc_tsv=os.path.join(f'{templates_dir}/atlas-{parc}_dseg.tsv')

            if session:
                tsv_out=os.path.join(f'{parc_dir}/sub-{subject}/ses-{session}/dwi/sub-{subject}_ses-{session}_desc-{parc}_model-noddi_results.tsv')

            else:
                tsv_out=os.path.join(f'{parc_dir}/sub-{subject}/dwi/sub-{subject}_desc-{parc}_model-noddi_results.tsv')

            if not os.path.exists(os.path.dirname(tsv_out)):
                os.makedirs(os.path.dirname(tsv_out))

            extract_noddi_parc_results(subject = subject,
                                    session = session,
                                    parc_file = parc_file,
                                    parc_tsv = parc_tsv,
                                    noddi_dir = noddi_dir,
                                    qsiprep_dir = qsiprep_dir,
                                    tsv_out = tsv_out,
                                    icvf_max_threshold = icvf_max_threshold)


if __name__ == '__main__':
    main()
