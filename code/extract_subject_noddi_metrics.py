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
    --parcellation <parc>...  List of parcellations to pull data from (defaults to all)
    --debug                  Debug logging
    -h, --help               Prints this message

DETAILS:

Part of Erin workflow for extracting from QSIPREP AMICO NODDI outputs

the parcellations dir (parc dir) serves as both input (for parcellations) and output directory

the icvf threshold will create a brainmask where icvf values are between zero and that threshold.
It is used to remove values of 1 from the mean calculations.
"""

from docopt import docopt

import os
import os.path
from glob import glob

import pandas as pd
import numpy as np
import seaborn as sns

import nilearn.plotting
from nilearn.image import math_img, resample_to_img, load_img
from bids.layout import parse_file_entities

import logging
logger = logging.getLogger(os.path.basename(__file__))


def noddi_filename(noddi_dir, subject, session, noddi_mdp):
    """
    Find the NODDI filename for a given subject/session/metric using a flexible pattern.
    """
    if session:
        pattern = (
            f"{noddi_dir}/sub-{subject}/ses-{session}/dwi/"
            f"sub-{subject}_ses-{session}_*space-T1w*_model-noddi_*-{noddi_mdp}_dwimap.nii*"
        )
    else:
        pattern = (
            f"{noddi_dir}/sub-{subject}/dwi/"
            f"sub-{subject}_*space-T1w*_model-noddi_*-{noddi_mdp}_dwimap.nii*"
        )

    matches = glob(pattern)
    if len(matches) == 0:
        raise FileNotFoundError(f"NODDI file not found with pattern: {pattern}")
    return matches[0]


def _compute_metric_stats_by_label(metric_img, label_img, label_ids, valid_mask=None):
    """
    Compute mean/std per label by explicit label ID matching.
    This avoids the bug from NiftiLabelsMasker positional outputs.
    """
    metric_data = load_img(metric_img).get_fdata()
    label_data = load_img(label_img).get_fdata().astype(np.int32)

    if valid_mask is None:
        valid_mask = np.ones(metric_data.shape, dtype=bool)
    else:
        valid_mask = valid_mask.astype(bool)

    means = []
    stdevs = []

    finite_mask = np.isfinite(metric_data)

    for idx in label_ids:
        roi_mask = (label_data == int(idx)) & valid_mask & finite_mask
        vals = metric_data[roi_mask]

        if vals.size == 0:
            means.append(np.nan)
            stdevs.append(np.nan)
        else:
            means.append(float(np.mean(vals)))
            stdevs.append(float(np.std(vals)))

    return np.array(means), np.array(stdevs)


def _compute_tissue_probabilities_by_label(tissue_img, label_img, label_ids, valid_mask=None):
    """
    Compute CSF/GM/WM probabilities within each parcel by explicit label matching.
    """
    tissue_data = load_img(tissue_img).get_fdata().astype(np.int32)
    label_data = load_img(label_img).get_fdata().astype(np.int32)

    if valid_mask is None:
        valid_mask = np.ones(tissue_data.shape, dtype=bool)
    else:
        valid_mask = valid_mask.astype(bool)

    dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}
    out = {f"{k}_prob": [] for k in dseg_labels}

    for idx in label_ids:
        roi_mask = (label_data == int(idx)) & valid_mask
        n = int(np.sum(roi_mask))

        if n == 0:
            for k in dseg_labels:
                out[f"{k}_prob"].append(np.nan)
            continue

        roi_vals = tissue_data[roi_mask]
        for k, v in dseg_labels.items():
            out[f"{k}_prob"].append(float(np.mean(roi_vals == v)))

    return {k: np.array(v) for k, v in out.items()}


def extract_noddi_parc_results(
    subject,
    session,
    parc_file,
    parc_tsv,
    noddi_dir,
    qsiprep_dir,
    tsv_out=None,
    icvf_max_threshold=0.99,
    strict_labels=False,
    autogen_labels=False
):
    """
    Extract parcel-wise NODDI stats (mean/stdev) + tissue probabilities from a labels image.

    Fixes the previous bug by matching parcel results by actual label index, not by array position.
    """
    parc_img = load_img(parc_file)
    parc_data = parc_img.get_fdata().astype(np.int32)

    # voxel volume
    pixdim = parc_img.header.get_zooms()[:3]
    voxel_size = float(pixdim[0] * pixdim[1] * pixdim[2])

    labels, counts = np.unique(parc_data, return_counts=True)
    results = pd.DataFrame({"index": labels, "n_vx_full": counts})
    results = results[results["index"] > 0].copy()
    results["index"] = results["index"].astype(int)
    results["n_vx_full"] = results["n_vx_full"].astype(int)
    results["size_full"] = results["n_vx_full"] * voxel_size

    # label names
    if parc_tsv and os.path.exists(parc_tsv):
        labeldf = pd.read_csv(parc_tsv, sep="\t")
        if not {"index", "name"}.issubset(labeldf.columns):
            raise ValueError(f"Label TSV missing required columns {{index,name}}: {parc_tsv}")

        labeldf = labeldf[["index", "name"]].copy()
        labeldf["index"] = labeldf["index"].astype(int)
        labeldf = labeldf.drop_duplicates("index")

        results = results.merge(labeldf, on="index", how="left")
    else:
        if strict_labels:
            raise FileNotFoundError(f"Parcellation label TSV not found: {parc_tsv}")
        if autogen_labels:
            results["name"] = results["index"].apply(lambda x: f"ROI_{int(x)}")
        else:
            results["name"] = np.nan

    label_ids = results["index"].to_numpy()

    # Build valid mask from ICVF only
    icvf_file = noddi_filename(noddi_dir, subject, session, "icvf")
    icvf_data = load_img(icvf_file).get_fdata()

    finite_icvf = np.isfinite(icvf_data)
    valid_mask = finite_icvf & (icvf_data > 0)

    if icvf_max_threshold is not None:
        valid_mask &= (icvf_data < float(icvf_max_threshold))

    # masked voxel counts per parcel
    n_vx_masked = []
    for idx in label_ids:
        n_vx_masked.append(int(np.sum((parc_data == int(idx)) & valid_mask)))

    results["n_vx_masked"] = np.array(n_vx_masked, dtype=int)
    results["coverage"] = np.where(
        results["n_vx_full"] > 0,
        results["n_vx_masked"] / results["n_vx_full"],
        np.nan
    )

    # metric extraction using explicit label mapping
    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)
        means, stdevs = _compute_metric_stats_by_label(
            metric_img=noddi_file,
            label_img=parc_file,
            label_ids=label_ids,
            valid_mask=valid_mask
        )
        results[f"{noddi_mdp}_mean"] = means
        results[f"{noddi_mdp}_stdev"] = stdevs

    # tissue probability from qsiprep dseg
    qsiprep_dseg = os.path.join(
        qsiprep_dir,
        f"sub-{subject}",
        "anat",
        f"sub-{subject}_dseg.nii.gz"
    )

    if os.path.exists(qsiprep_dseg):
        tissue_img = resample_to_img(qsiprep_dseg, parc_img, interpolation="nearest")
        tissue_probs = _compute_tissue_probabilities_by_label(
            tissue_img=tissue_img,
            label_img=parc_file,
            label_ids=label_ids,
            valid_mask=valid_mask
        )

        for col, vals in tissue_probs.items():
            results[col] = vals

        prob_cols = ["CSF_prob", "GM_prob", "WM_prob"]
        results["tissue"] = results[prob_cols].idxmax(axis=1).str.replace("_prob", "", regex=False)
        results["tissue_prob"] = results[prob_cols].max(axis=1)
    else:
        for tissue in ["CSF", "GM", "WM"]:
            results[f"{tissue}_prob"] = np.nan
        results["tissue"] = np.nan
        results["tissue_prob"] = np.nan

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

    for c in outcols:
        if c not in results.columns:
            results[c] = np.nan

    results = results[outcols]

    if tsv_out:
        os.makedirs(os.path.dirname(tsv_out), exist_ok=True)
        results.to_csv(tsv_out, index=False, sep="\t")

    return results


def make_noddi_3tissues_plot(subject, session, noddi_dir, qsiprep_dir, out_png=None, icvf_max_threshold=0.99):
    """
    Make density plots by dseg tissue types.
    """
    qsiprep_dseg = os.path.join(f"{qsiprep_dir}/sub-{subject}/anat/sub-{subject}_dseg.nii.gz")
    dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}

    df0 = pd.DataFrame(columns=["tissue", "value", "noddi"])

    good_tissue_img = None

    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)

        if noddi_mdp == "icvf":
            tissue_img = resample_to_img(qsiprep_dseg, noddi_file, interpolation="nearest")
            good_dwi = math_img(f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})", img1=noddi_file)
            good_tissue_img = math_img("img1 * img2", img1=good_dwi, img2=tissue_img)

        for tissue, value in dseg_labels.items():
            noddi_tissue = math_img(f"(img1 == {value}) * img2", img1=good_tissue_img, img2=noddi_file)
            noddi_flat = noddi_tissue.get_fdata().flatten()
            noddi_flat = noddi_flat[noddi_flat > 0]
            df1 = pd.DataFrame({"tissue": tissue, "noddi": noddi_mdp, "value": noddi_flat})
            df0 = pd.concat([df0, df1], axis=0)

    plt = sns.FacetGrid(df0, col="noddi", hue="tissue")
    plt.map_dataframe(sns.kdeplot, x="value", clip=[0, 1])
    plt.add_legend()
    plt.fig.subplots_adjust(top=0.9)
    plt.fig.suptitle(
        f"sub-{subject} ses-{session} NODDI values by tissue",
        verticalalignment="bottom"
    )

    if out_png:
        plt.savefig(out_png)

    return plt


def make_dseg_qsi_qa_image(subject, session, noddi_mdp, noddi_dir, parc_file, parc_name, out_png):
    """
    Output a QA figure of parcellation on top of noddi map.
    """
    noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)

    plt = nilearn.plotting.plot_roi(
        roi_img=parc_file,
        bg_img=noddi_file,
        alpha=0.4,
        display_mode="mosaic",
        title=f"{subject} {parc_name} on noddi {noddi_mdp}",
        output_file=out_png
    )
    return plt


def main():
    arguments = docopt(__doc__)

    logger.setLevel(logging.WARNING)
    if arguments["--debug"]:
        logger.setLevel(logging.DEBUG)

    logger.info(arguments)

    parc_dir = arguments["--parc-dir"]
    qsiprep_dir = arguments["--qsiprep-dir"]
    noddi_dir = arguments["--amico-noddi-dir"]

    subject = str(arguments["--subject"]).replace("sub-", "")
    session = arguments["--session"]
    icvf_max_threshold = float(arguments["--icvf-thresh"]) if arguments["--icvf-thresh"] is not None else None

    templates_dir = parc_dir
    parc_list = arguments["--parcellation"]

    if not parc_list:
        parc_list = []
        parc_files = glob(f"{parc_dir}/sub-{subject}/anat/sub-{subject}_space-ACPC_desc-*_dseg.nii.gz")

        if len(parc_files) > 0:
            for parc_file in parc_files:
                parc = parse_file_entities(parc_file)["desc"]
                parc_list.append(parc)
        else:
            logger.error(f"No ACPC parcellations found in {parc_dir}/sub-{subject}/anat")
            return
    else:
        if isinstance(parc_list, str):
            parc_list = [parc_list]

        for parc in parc_list:
            parc_file = os.path.join(
                f"{parc_dir}/sub-{subject}/anat/sub-{subject}_space-ACPC_desc-{parc}_dseg.nii.gz"
            )
            if not os.path.exists(parc_file):
                logger.error(f"Input parcellation file {parc_file} not found")
                return

    if session:
        session = str(session).replace("ses-", "")
        sessions = [session]
        noddi_file = noddi_filename(noddi_dir, subject, session, "icvf")
        if not os.path.exists(noddi_file):
            logger.error(f"Input {noddi_file} not found")
            return
    else:
        blist = glob(f"{noddi_dir}/sub-{subject}/*/dwi/*model-noddi_mdp-icvf*")
        b2 = glob(f"{noddi_dir}/sub-{subject}/dwi/*model-noddi_mdp-icvf*")
        blist.extend(b2)
        if len(blist) > 0:
            ses_list = []
            for bfile in blist:
                ses = parse_file_entities(bfile).get("session")
                ses_list.append(ses)
            sessions = list(set(ses_list))
            if len(sessions) < 1:
                sessions = [None]
        else:
            logger.error(f"No input noddi files found in {noddi_dir}/sub-{subject}")
            return

    for session in sessions:
        if session:
            noddi_3tissue_out = os.path.join(
                f"{parc_dir}/sub-{subject}/figures/sub-{subject}_ses-{session}_desc-dsegtissue_model-noddi_density.png"
            )
        else:
            noddi_3tissue_out = os.path.join(
                f"{parc_dir}/sub-{subject}/figures/sub-{subject}_desc-dsegtissue_model-noddi_density.png"
            )

        os.makedirs(os.path.dirname(noddi_3tissue_out), exist_ok=True)

        make_noddi_3tissues_plot(
            subject=subject,
            session=session,
            noddi_dir=noddi_dir,
            qsiprep_dir=qsiprep_dir,
            out_png=noddi_3tissue_out,
            icvf_max_threshold=icvf_max_threshold
        )

        for parc in parc_list:
            parc_file = os.path.join(
                f"{parc_dir}/sub-{subject}/anat/sub-{subject}_space-ACPC_desc-{parc}_dseg.nii.gz"
            )

            for noddi_mdp in ["od", "icvf"]:
                if session:
                    out_png = os.path.join(
                        f"{parc_dir}/sub-{subject}/figures/sub-{subject}_ses-{session}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png"
                    )
                else:
                    out_png = os.path.join(
                        f"{parc_dir}/sub-{subject}/figures/sub-{subject}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png"
                    )

                make_dseg_qsi_qa_image(
                    subject=subject,
                    session=session,
                    noddi_mdp=noddi_mdp,
                    noddi_dir=noddi_dir,
                    parc_file=parc_file,
                    parc_name=parc,
                    out_png=out_png
                )

            if parc in ["wmparc", "aparcaseg"]:
                parc_tsv = os.path.join(f"{templates_dir}/desc-FreeSurferAll_dseg.tsv")
            else:
                parc_tsv = os.path.join(f"{templates_dir}/atlas-{parc}_dseg.tsv")

            if session:
                tsv_out = os.path.join(
                    f"{parc_dir}/sub-{subject}/ses-{session}/dwi/sub-{subject}_ses-{session}_desc-{parc}_model-noddi_results.tsv"
                )
            else:
                tsv_out = os.path.join(
                    f"{parc_dir}/sub-{subject}/dwi/sub-{subject}_desc-{parc}_model-noddi_results.tsv"
                )

            os.makedirs(os.path.dirname(tsv_out), exist_ok=True)

            extract_noddi_parc_results(
                subject=subject,
                session=session,
                parc_file=parc_file,
                parc_tsv=parc_tsv,
                noddi_dir=noddi_dir,
                qsiprep_dir=qsiprep_dir,
                tsv_out=tsv_out,
                icvf_max_threshold=icvf_max_threshold
            )


if __name__ == "__main__":
    main()
