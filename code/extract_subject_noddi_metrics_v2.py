#!/usr/bin/env python3
"""
Extracts NODDI metrics for dseg files in subject folder (T1w parcellations; no ACPC).

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
    --parcellation <parc>    List of parcellations to pull data from (defaults to all)
    --debug                  Debug logging
    -h, --help               Prints this message
"""

from docopt import docopt

import os
from glob import glob
import logging

import pandas as pd
import numpy as np
import seaborn as sns

import nilearn.plotting
import nilearn.image
from nilearn.image import math_img, resample_to_img
from nilearn.maskers import NiftiLabelsMasker
from bids.layout import parse_file_entities

logger = logging.getLogger(os.path.basename(__file__))


def noddi_filename(noddi_dir, subject, session, noddi_mdp):
    """
    Find the NODDI filename for a given subject/session/metric using a flexible pattern.
    Assumes outputs are in space-T1w (QSIPrep/AMICO NODDI).
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


def find_parc_files_t1w(parc_dir, subject):
    """
    NEW: find T1w-space parcellations produced by Step 2 (no ACPC).
    """
    return glob(f"{parc_dir}/sub-{subject}/anat/sub-{subject}_space-T1w_desc-*_dseg_on-dwiref.nii.gz")


def parc_file_t1w(parc_dir, subject, parc_desc):
    """
    NEW: build expected T1w parcellation filename.
    """
    return os.path.join(
        parc_dir, f"sub-{subject}", "anat", f"sub-{subject}_space-T1w_desc-{parc_desc}_dseg_on-dwiref.nii.gz"
    )


def _masker_to_series(masker: NiftiLabelsMasker, values_1d: np.ndarray) -> pd.Series:
    """
    Map masker output back to parcel indices safely.

    masker.labels_ typically contains the label IDs found (excluding background).
    This avoids wrong assignments when some labels are missing.
    """
    if not hasattr(masker, "labels_") or masker.labels_ is None:
        # Fallback: assume contiguous ordering (less safe)
        idx = np.arange(1, len(values_1d) + 1)
        return pd.Series(values_1d, index=idx)

    label_ids = np.array(masker.labels_, dtype=int)
    return pd.Series(values_1d, index=label_ids)


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
    autogen_labels=False,
):
    # Load parcellation image
    parc_img = nilearn.image.load_img(parc_file)

    # voxel volume (mm^3)
    pixdim = parc_img.header.get_zooms()[:3]
    voxel_size = float(pixdim[0] * pixdim[1] * pixdim[2])

    # Unique labels + voxel counts
    data = parc_img.get_fdata()
    labels, counts = np.unique(data.astype(np.int32), return_counts=True)

    results = pd.DataFrame({"index": labels, "n_vx_full": counts})
    results = results[results["index"] > 0].copy()
    results["size_full"] = results["n_vx_full"] * voxel_size

    # ---- label names (TSV) ----
    if parc_tsv and os.path.exists(parc_tsv):
        labeldf = pd.read_csv(parc_tsv, sep="\t")
        if not {"index", "name"}.issubset(labeldf.columns):
            raise ValueError(f"Label TSV missing required columns {{index,name}}: {parc_tsv}")

        labeldf = labeldf[["index", "name"]].copy()
        labeldf["index"] = labeldf["index"].astype(int)
        labeldf = labeldf.drop_duplicates("index").set_index("index")

        results = results.set_index("index").join(labeldf, how="left").reset_index()
    else:
        if strict_labels:
            raise FileNotFoundError(f"Parcellation label TSV not found: {parc_tsv}")
        if autogen_labels:
            results["name"] = results["index"].apply(lambda x: f"ROI_{int(x)}")
        else:
            results["name"] = np.nan

    good_parc_img = parc_img

    # ---- NODDI metrics ----
    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)

        if noddi_mdp == "icvf":
            if icvf_max_threshold is not None:
                good_dwi = math_img(
                    f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})",
                    img1=noddi_file
                )
                good_parc_img = math_img("img1 * img2", img1=good_dwi, img2=parc_img)
            else:
                good_parc_img = parc_img

            # masked voxel counts per parcel for coverage
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

        # Mean (SAFE mapping)
        masker_mean = NiftiLabelsMasker(labels_img=good_parc_img, strategy="mean")
        mean_vals = masker_mean.fit_transform(noddi_file).ravel()
        s_mean = _masker_to_series(masker_mean, mean_vals)
        results[f"{noddi_mdp}_mean"] = results["index"].map(s_mean)

        # Std (SAFE mapping)
        masker_std = NiftiLabelsMasker(labels_img=good_parc_img, strategy="standard_deviation")
        std_vals = masker_std.fit_transform(noddi_file).ravel()
        s_std = _masker_to_series(masker_std, std_vals)
        results[f"{noddi_mdp}_stdev"] = results["index"].map(s_std)

    # ---- Tissue probability (GM/WM/CSF) from qsiprep dseg ----
    qsiprep_dseg = os.path.join(qsiprep_dir, f"sub-{subject}", "anat", f"sub-{subject}_dseg.nii.gz")
    if os.path.exists(qsiprep_dseg):
        tissue_img = resample_to_img(qsiprep_dseg, good_parc_img, interpolation="nearest")

        dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}
        for tissue, value in dseg_labels.items():
            tissue_mask = math_img(f"img1 == {int(value)}", img1=tissue_img)
            tmasker = NiftiLabelsMasker(labels_img=good_parc_img, strategy="mean")
            tvals = tmasker.fit_transform(tissue_mask).ravel()
            s_t = _masker_to_series(tmasker, tvals)
            results[f"{tissue}_prob"] = results["index"].map(s_t)

        results["tissue"] = results[["CSF_prob", "GM_prob", "WM_prob"]].idxmax(axis=1).str.replace("_prob", "")
        results["tissue_prob"] = results[["CSF_prob", "GM_prob", "WM_prob"]].max(axis=1)
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
    qsiprep_dseg = os.path.join(qsiprep_dir, f"sub-{subject}", "anat", f"sub-{subject}_dseg.nii.gz")
    dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}

    df0 = pd.DataFrame(columns=["tissue", "value", "noddi"])

    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)

        if noddi_mdp == "icvf":
            tissue_img = resample_to_img(qsiprep_dseg, noddi_file, interpolation="nearest")
            good_dwi = math_img(f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})", img1=noddi_file)
            good_tissue_img = math_img("img1*img2", img1=good_dwi, img2=tissue_img)

        for tissue, value in dseg_labels.items():
            noddi_tissue = math_img(f"(img1 == {value})*img2", img1=good_tissue_img, img2=noddi_file)
            noddi_flat = noddi_tissue.get_fdata().flatten()
            noddi_flat = noddi_flat[noddi_flat > 0]
            df1 = pd.DataFrame({"tissue": tissue, "noddi": noddi_mdp, "value": noddi_flat})
            df0 = pd.concat([df0, df1], axis=0)

    g = sns.FacetGrid(df0, col="noddi", hue="tissue")
    g.map_dataframe(sns.kdeplot, x="value", clip=[0, 1])
    g.add_legend()
    g.fig.subplots_adjust(top=0.9)
    g.fig.suptitle(f"sub-{subject} ses-{session} NODDI values by tissue", verticalalignment="bottom")

    if out_png:
        g.savefig(out_png)

    return g


def make_dseg_qsi_qa_image(subject, session, noddi_mdp, noddi_dir, parc_file, parc_name, out_png):
    noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)
    return nilearn.plotting.plot_roi(
        roi_img=parc_file,
        bg_img=noddi_file,
        alpha=0.4,
        display_mode="mosaic",
        title=f"{subject} {parc_name} on noddi {noddi_mdp}",
        output_file=out_png,
    )


def main():
    arguments = docopt(__doc__)

    logger.setLevel(logging.WARNING)
    if arguments["--debug"]:
        logger.setLevel(logging.DEBUG)

    parc_dir = arguments["--parc-dir"]
    qsiprep_dir = arguments["--qsiprep-dir"]
    noddi_dir = arguments["--amico-noddi-dir"]

    subject = str(arguments["--subject"]).replace("sub-", "")
    session = arguments["--session"]
    icvf_max_threshold = float(arguments["--icvf-thresh"])

    templates_dir = parc_dir

    parc_list = arguments["--parcellation"]

    # --- NEW DEFAULT: discover T1w parcellations ---
    if not parc_list:
        parc_list = []
        parc_files = find_parc_files_t1w(parc_dir, subject)
        if len(parc_files) > 0:
            for pf in parc_files:
                parc = parse_file_entities(pf)["desc"]
                parc_list.append(parc)
        else:
            logger.error(f"No T1w parcellations found in {parc_dir}/sub-{subject}/anat")
            return
    else:
        parc = parc_list
        pf = parc_file_t1w(parc_dir, subject, parc)
        if not os.path.exists(pf):
            logger.error(f"Input parcellation file {pf} not found")
            return

    # sessions discovery
    if session:
        session = str(session).replace("ses-", "")
        sessions = [session]
        _ = noddi_filename(noddi_dir, subject, session, "icvf")
    else:
        blist = glob(f"{noddi_dir}/sub-{subject}/*/dwi/*model-noddi_mdp-icvf*")
        blist.extend(glob(f"{noddi_dir}/sub-{subject}/dwi/*model-noddi_mdp-icvf*"))
        if len(blist) > 0:
            ses_list = [parse_file_entities(bf).get("session") for bf in blist]
            sessions = list(set([s for s in ses_list if s is not None]))
            if len(sessions) < 1:
                sessions = [None]
        else:
            logger.error(f"No input noddi files found in {noddi_dir}/sub-{subject}")
            return

    # Make density plot across tissues
    for session in sessions:
        if session:
            noddi_3tissue_out = os.path.join(parc_dir, f"sub-{subject}", "figures",
                                            f"sub-{subject}_ses-{session}_desc-dsegtissue_model-noddi_density.png")
        else:
            noddi_3tissue_out = os.path.join(parc_dir, f"sub-{subject}", "figures",
                                            f"sub-{subject}_desc-dsegtissue_model-noddi_density.png")

        os.makedirs(os.path.dirname(noddi_3tissue_out), exist_ok=True)

        make_noddi_3tissues_plot(
            subject=subject,
            session=session,
            noddi_dir=noddi_dir,
            qsiprep_dir=qsiprep_dir,
            out_png=noddi_3tissue_out,
            icvf_max_threshold=icvf_max_threshold,
        )

        # Loop over parcellations
        for parc in parc_list:
            parc_file = parc_file_t1w(parc_dir, subject, parc)

            # QA on OD and ICVF
            for noddi_mdp in ["od", "icvf"]:
                if session:
                    out_png = os.path.join(parc_dir, f"sub-{subject}", "figures",
                                           f"sub-{subject}_ses-{session}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png")
                else:
                    out_png = os.path.join(parc_dir, f"sub-{subject}", "figures",
                                           f"sub-{subject}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png")

                make_dseg_qsi_qa_image(
                    subject=subject,
                    session=session,
                    noddi_mdp=noddi_mdp,
                    noddi_dir=noddi_dir,
                    parc_file=parc_file,
                    parc_name=parc,
                    out_png=out_png,
                )

            # label TSV selection
            if parc in ["wmparc", "aparcaseg"]:
                parc_tsv = os.path.join(templates_dir, "desc-FreeSurferAll_dseg.tsv")
            else:
                parc_tsv = os.path.join(templates_dir, f"atlas-{parc}_dseg.tsv")

            # output TSV path
            if session:
                tsv_out = os.path.join(parc_dir, f"sub-{subject}", f"ses-{session}", "dwi",
                                       f"sub-{subject}_ses-{session}_desc-{parc}_model-noddi_results.tsv")
            else:
                tsv_out = os.path.join(parc_dir, f"sub-{subject}", "dwi",
                                       f"sub-{subject}_desc-{parc}_model-noddi_results.tsv")

            os.makedirs(os.path.dirname(tsv_out), exist_ok=True)

            extract_noddi_parc_results(
                subject=subject,
                session=session,
                parc_file=parc_file,
                parc_tsv=parc_tsv,
                noddi_dir=noddi_dir,
                qsiprep_dir=qsiprep_dir,
                tsv_out=tsv_out,
                icvf_max_threshold=icvf_max_threshold,
            )


if __name__ == "__main__":
    main()
