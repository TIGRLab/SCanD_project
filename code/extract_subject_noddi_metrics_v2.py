#!/usr/bin/env python3
"""
Extracts NODDI metrics for dseg files in subject folder.

FINAL FIX:
- ALWAYS resample parcellation onto the exact NODDI dwimap grid before:
  - coverage computation
  - parcel-wise stats
  - QA overlay
This removes all dwiref/dwimap grid mismatch issues.

Usage:
  extract_subject_noddi_metrics_v2.py --subject=<subject> --parc-dir=<parc-dir> --qsiprep-dir=<qsiprep-dir> --amico-noddi-dir=<amico-noddi> [--session=<session>] [--icvf-thresh=<thres>] [--parcellation=<parc>] [--debug]

Options:
  --subject=<subject>            BIDS subject id (e.g., MRP0007 or sub-MRP0007)
  --parc-dir=<parc-dir>          Parcellations + outputs directory (e.g., /parc)
  --qsiprep-dir=<qsiprep-dir>    QSIPrep derivatives root (e.g., /qsiprep)
  --amico-noddi-dir=<amico-noddi> AMICO-NODDI derivatives root (e.g., /noddi)
  --session=<session>            Session label without "ses-" (e.g., 01)
  --icvf-thresh=<thres>          Threshold for mask [default: 0.99]
  --parcellation=<parc>          Optional single parcellation desc to run
  --debug                        Verbose logging
"""

from docopt import docopt
import os
from glob import glob
import logging

import pandas as pd
import numpy as np
import seaborn as sns

import nilearn.image
import nilearn.plotting
from nilearn.image import math_img, resample_to_img
from nilearn.maskers import NiftiLabelsMasker
from bids.layout import parse_file_entities

logger = logging.getLogger(os.path.basename(__file__))


def noddi_filename(noddi_dir, subject, session, noddi_mdp):
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
    if not matches:
        raise FileNotFoundError(f"NODDI file not found with pattern: {pattern}")
    return matches[0]


def find_parc_files_t1w(parc_dir, subject):
    # FINAL: we read the original T1w parcellations produced in Step 2
    return glob(f"{parc_dir}/sub-{subject}/anat/sub-{subject}_space-T1w_desc-*_dseg.nii.gz")


def parc_file_t1w(parc_dir, subject, parc_desc):
    return os.path.join(parc_dir, f"sub-{subject}", "anat", f"sub-{subject}_space-T1w_desc-{parc_desc}_dseg.nii.gz")


def _masker_to_series(masker: NiftiLabelsMasker, values_1d: np.ndarray) -> pd.Series:
    if not hasattr(masker, "labels_") or masker.labels_ is None:
        idx = np.arange(1, len(values_1d) + 1)
        return pd.Series(values_1d, index=idx)
    label_ids = np.array(masker.labels_, dtype=int)
    return pd.Series(values_1d, index=label_ids)


def _parcel_counts(parc_img):
    data = parc_img.get_fdata().astype(np.int32)
    labels, counts = np.unique(data, return_counts=True)
    df = pd.DataFrame({"index": labels, "n_vx": counts})
    df = df[df["index"] > 0].copy()
    return df


def extract_noddi_parc_results(
    subject,
    session,
    parc_file,
    parc_tsv,
    noddi_dir,
    qsiprep_dir,
    tsv_out=None,
    icvf_max_threshold=0.99,
):
    parc_img_native = nilearn.image.load_img(parc_file)

    # We will build results on the parcellation AFTER it is resampled to the NODDI grid.
    # That ensures voxel counts and coverage are computed in the SAME grid used for stats.

    # --- label names ---
    labeldf = None
    if parc_tsv and os.path.exists(parc_tsv):
        labeldf = pd.read_csv(parc_tsv, sep="\t")
        if not {"index", "name"}.issubset(labeldf.columns):
            raise ValueError(f"Label TSV missing required columns {{index,name}}: {parc_tsv}")
        labeldf = labeldf[["index", "name"]].copy()
        labeldf["index"] = labeldf["index"].astype(int)
        labeldf = labeldf.drop_duplicates("index").set_index("index")

    # We use ICVF dwimap as the “reference grid” for parcel voxel counts/coverage,
    # since the coverage mask is defined from ICVF.
    icvf_file = noddi_filename(noddi_dir, subject, session, "icvf")
    icvf_img = nilearn.image.load_img(icvf_file)

    # FINAL FIX: resample ROI -> ICVF grid
    parc_on_icvf = resample_to_img(parc_img_native, icvf_img, interpolation="nearest")

    # voxel volume
    pixdim = parc_on_icvf.header.get_zooms()[:3]
    voxel_size = float(pixdim[0] * pixdim[1] * pixdim[2])

    full_df = _parcel_counts(parc_on_icvf).rename(columns={"n_vx": "n_vx_full"})
    full_df["size_full"] = full_df["n_vx_full"] * voxel_size

    results = full_df.copy()
    if labeldf is not None:
        results = results.set_index("index").join(labeldf, how="left").reset_index()
    else:
        results["name"] = np.nan

    # ---- coverage mask from ICVF ----
    if icvf_max_threshold is not None:
        good_mask = math_img(
            f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})",
            img1=icvf_img
        )
        good_parc = math_img("img1 * img2", img1=good_mask, img2=parc_on_icvf)
    else:
        good_parc = parc_on_icvf

    masked_df = _parcel_counts(good_parc).rename(columns={"n_vx": "n_vx_masked"})
    results = results.merge(masked_df, on="index", how="left")
    results["n_vx_masked"] = results["n_vx_masked"].fillna(0).astype(int)
    results["coverage"] = np.where(
        results["n_vx_full"] > 0,
        results["n_vx_masked"] / results["n_vx_full"],
        np.nan
    )

    # ---- NODDI stats (each metric: resample ROI to THAT metric’s grid) ----
    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)
        noddi_img = nilearn.image.load_img(noddi_file)

        # FINAL FIX: always put parcels on the metric grid
        parc_on_metric = resample_to_img(parc_img_native, noddi_img, interpolation="nearest")

        # use the same “good mask” logic only for icvf-based exclusion
        if noddi_mdp == "icvf" and icvf_max_threshold is not None:
            good_mask_metric = math_img(
                f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})",
                img1=noddi_img
            )
            parc_for_stats = math_img("img1 * img2", img1=good_mask_metric, img2=parc_on_metric)
        else:
            # for od/isovf we still want the same parcel grid, but no icvf thresholding
            parc_for_stats = parc_on_metric

        # Mean
        masker_mean = NiftiLabelsMasker(labels_img=parc_for_stats, strategy="mean")
        mean_vals = masker_mean.fit_transform(noddi_img).ravel()
        s_mean = _masker_to_series(masker_mean, mean_vals)
        results[f"{noddi_mdp}_mean"] = results["index"].map(s_mean)

        # Std
        masker_std = NiftiLabelsMasker(labels_img=parc_for_stats, strategy="standard_deviation")
        std_vals = masker_std.fit_transform(noddi_img).ravel()
        s_std = _masker_to_series(masker_std, std_vals)
        results[f"{noddi_mdp}_stdev"] = results["index"].map(s_std)

    # ---- Tissue probability from qsiprep dseg (resample dseg -> ICVF grid) ----
    qsiprep_dseg = os.path.join(qsiprep_dir, f"sub-{subject}", "anat", f"sub-{subject}_dseg.nii.gz")
    if os.path.exists(qsiprep_dseg):
        tissue_img = resample_to_img(qsiprep_dseg, icvf_img, interpolation="nearest")

        dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}
        for tissue, value in dseg_labels.items():
            tissue_mask = math_img(f"img1 == {int(value)}", img1=tissue_img)
            tmasker = NiftiLabelsMasker(labels_img=parc_on_icvf, strategy="mean")
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


def make_dseg_qsi_qa_image(subject, session, noddi_mdp, noddi_dir, parc_file, parc_name, out_png):
    parc_img_native = nilearn.image.load_img(parc_file)
    noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)
    noddi_img = nilearn.image.load_img(noddi_file)

    # FINAL FIX: ROI on exact bg grid
    parc_on_bg = resample_to_img(parc_img_native, noddi_img, interpolation="nearest")

    return nilearn.plotting.plot_roi(
        roi_img=parc_on_bg,
        bg_img=noddi_img,
        alpha=0.4,
        display_mode="mosaic",
        title=f"{subject} {parc_name} on noddi {noddi_mdp}",
        output_file=out_png,
    )


def make_noddi_3tissues_plot(subject, session, noddi_dir, qsiprep_dir, out_png=None, icvf_max_threshold=0.99):
    qsiprep_dseg = os.path.join(qsiprep_dir, f"sub-{subject}", "anat", f"sub-{subject}_dseg.nii.gz")
    dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}

    df0 = pd.DataFrame(columns=["tissue", "value", "noddi"])

    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)
        noddi_img = nilearn.image.load_img(noddi_file)

        if noddi_mdp == "icvf":
            tissue_img = resample_to_img(qsiprep_dseg, noddi_img, interpolation="nearest")
            good_dwi = math_img(f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})", img1=noddi_img)
            good_tissue_img = math_img("img1*img2", img1=good_dwi, img2=tissue_img)

        for tissue, value in dseg_labels.items():
            noddi_tissue = math_img(f"(img1 == {value})*img2", img1=good_tissue_img, img2=noddi_img)
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


def main():
    args = docopt(__doc__)
    logger.setLevel(logging.DEBUG if args["--debug"] else logging.WARNING)

    parc_dir = args["--parc-dir"]
    qsiprep_dir = args["--qsiprep-dir"]
    noddi_dir = args["--amico-noddi-dir"]

    subject = str(args["--subject"]).replace("sub-", "")
    session = args["--session"]
    icvf_max_threshold = float(args["--icvf-thresh"])

    parc_list = args["--parcellation"]

    if not parc_list:
        parc_files = find_parc_files_t1w(parc_dir, subject)
        if not parc_files:
            logger.error(f"No T1w parcellations found in {parc_dir}/sub-{subject}/anat")
            return
        parc_list = [parse_file_entities(pf)["desc"] for pf in parc_files]
    else:
        pf = parc_file_t1w(parc_dir, subject, parc_list)
        if not os.path.exists(pf):
            logger.error(f"Input parcellation file {pf} not found")
            return

    # sessions
    if session:
        session = str(session).replace("ses-", "")
        sessions = [session]
        _ = noddi_filename(noddi_dir, subject, session, "icvf")
    else:
        blist = glob(f"{noddi_dir}/sub-{subject}/*/dwi/*model-noddi_mdp-icvf*")
        blist.extend(glob(f"{noddi_dir}/sub-{subject}/dwi/*model-noddi_mdp-icvf*"))
        ses_list = [parse_file_entities(bf).get("session") for bf in blist]
        sessions = list(set([s for s in ses_list if s is not None])) or [None]

    templates_dir = parc_dir

    for ses in sessions:
        # QA density
        fig_dir = os.path.join(parc_dir, f"sub-{subject}", "figures")
        os.makedirs(fig_dir, exist_ok=True)

        density_out = os.path.join(
            fig_dir,
            f"sub-{subject}_ses-{ses}_desc-dsegtissue_model-noddi_density.png" if ses else
            f"sub-{subject}_desc-dsegtissue_model-noddi_density.png"
        )
        make_noddi_3tissues_plot(subject, ses, noddi_dir, qsiprep_dir, out_png=density_out, icvf_max_threshold=icvf_max_threshold)

        for parc in parc_list:
            parc_path = parc_file_t1w(parc_dir, subject, parc)

            # QA overlays (now always aligned)
            for noddi_mdp in ["od", "icvf"]:
                qa_out = os.path.join(
                    fig_dir,
                    f"sub-{subject}_ses-{ses}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png" if ses else
                    f"sub-{subject}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png"
                )
                make_dseg_qsi_qa_image(subject, ses, noddi_mdp, noddi_dir, parc_path, parc, qa_out)

            # label TSV
            if parc in ["wmparc", "aparcaseg"]:
                parc_tsv = os.path.join(templates_dir, "desc-FreeSurferAll_dseg.tsv")
            else:
                parc_tsv = os.path.join(templates_dir, f"atlas-{parc}_dseg.tsv")

            # output TSV
            out_dir = os.path.join(parc_dir, f"sub-{subject}", f"ses-{ses}", "dwi") if ses else os.path.join(parc_dir, f"sub-{subject}", "dwi")
            os.makedirs(out_dir, exist_ok=True)

            tsv_out = os.path.join(
                out_dir,
                f"sub-{subject}_ses-{ses}_desc-{parc}_model-noddi_results.tsv" if ses else
                f"sub-{subject}_desc-{parc}_model-noddi_results.tsv"
            )

            extract_noddi_parc_results(
                subject=subject,
                session=ses,
                parc_file=parc_path,
                parc_tsv=parc_tsv,
                noddi_dir=noddi_dir,
                qsiprep_dir=qsiprep_dir,
                tsv_out=tsv_out,
                icvf_max_threshold=icvf_max_threshold,
            )


if __name__ == "__main__":
    main()
