#!/usr/bin/env python3
"""
Extract NODDI metrics per parcel and write TSV + QA PNGs.

Usage:
  extract_subject_noddi_metrics_v2.py --subject <subject> --parc-dir <parc-dir> --qsiprep-dir <qsiprep-dir> --amico-noddi-dir <amico-noddi-dir> [--session <session>] [--icvf-thresh <thres>] [--parcellation <parc>] [--debug]

Options:
  --subject <subject>              Subject ID (e.g. MRP0007 or sub-MRP0007)
  --parc-dir <parc-dir>            Parcellations + outputs root (e.g. /parc)
  --qsiprep-dir <qsiprep-dir>      QSIPrep derivatives root (e.g. /qsiprep)
  --amico-noddi-dir <amico-noddi-dir>  AMICO-NODDI derivatives root (e.g. /noddi)
  --session <session>              Session label without "ses-" (e.g. 01) [default: ]
  --icvf-thresh <thres>            ICVF threshold for mask [default: 0.99]
  --parcellation <parc>            Run only one parcellation desc (e.g. 4S1056Parcels)
  --debug                          Verbose logging
"""

from __future__ import annotations

from docopt import docopt
import os
from glob import glob
import logging

import numpy as np
import pandas as pd
import seaborn as sns

import nibabel as nib
import nilearn.image
import nilearn.plotting
from nilearn.image import math_img, resample_to_img, new_img_like
from nilearn.maskers import NiftiLabelsMasker
from bids.layout import parse_file_entities


logger = logging.getLogger("extract_subject_noddi_metrics_v2")


# -----------------------------
# Helpers
# -----------------------------

def _force_xform_like(img: nib.Nifti1Image, ref: nib.Nifti1Image) -> nib.Nifti1Image:
    """Force qform/sform + affine to match ref exactly."""
    hdr = img.header.copy()
    hdr.set_qform(ref.affine, code=1)
    hdr.set_sform(ref.affine, code=1)
    return nib.Nifti1Image(img.get_fdata(dtype=np.float32), ref.affine, header=hdr)


def _load_img(path: str) -> nib.Nifti1Image:
    return nilearn.image.load_img(path)


def _parcel_counts(parc_img: nib.Nifti1Image) -> pd.DataFrame:
    data = np.asarray(parc_img.get_fdata(), dtype=np.int32)
    labels, counts = np.unique(data, return_counts=True)
    df = pd.DataFrame({"index": labels, "n_vx": counts})
    df = df[df["index"] > 0].copy()
    return df


def _masker_to_series(masker: NiftiLabelsMasker, values_1d: np.ndarray) -> pd.Series:
    # safest mapping when labels missing
    if hasattr(masker, "labels_") and masker.labels_ is not None:
        label_ids = np.array(masker.labels_, dtype=int)
        return pd.Series(values_1d, index=label_ids)
    # fallback (less safe)
    idx = np.arange(1, len(values_1d) + 1)
    return pd.Series(values_1d, index=idx)


def noddi_filename(noddi_dir: str, subject: str, session: str | None, noddi_mdp: str) -> str:
    """
    Robust NODDI file selection:
      - must be model-noddi
      - must match requested metric (mdp / metric / substring)
      - prefer space-T1w if available, otherwise fallback (ACPC/None) instead of hard failing
    """
    if session:
        dwi_dir = f"{noddi_dir}/sub-{subject}/ses-{session}/dwi"
    else:
        dwi_dir = f"{noddi_dir}/sub-{subject}/dwi"

    cands = sorted(glob(f"{dwi_dir}/*.nii*"))
    if not cands:
        raise FileNotFoundError(f"No NIfTIs found under {dwi_dir}")

    keep: list[tuple[str, dict]] = []
    for p in cands:
        ent = parse_file_entities(p)

        if ent.get("model") != "noddi":
            continue

        metric = ent.get("mdp") or ent.get("metric") or ent.get("map")
        # prefer entity match; fallback to substring if naming is weird
        if metric is not None:
            if str(metric) != noddi_mdp:
                continue
        else:
            if f"mdp-{noddi_mdp}" not in p and f"-{noddi_mdp}_" not in p and noddi_mdp not in p:
                continue

        keep.append((p, ent))

    if not keep:
        raise FileNotFoundError(f"No NODDI {noddi_mdp} files matched under {dwi_dir}")

    def rank(item):
        p, ent = item
        space = ent.get("space")
        return (
            2 if space == "T1w" else (1 if space is not None else 0),
            1 if "dwimap" in p else 0,
            len(p),
        )

    keep_sorted = sorted(keep, key=rank, reverse=True)
    chosen, ent = keep_sorted[0]
    logger.warning(
        f"[NODDI PICK] subj={subject} ses={session} mdp={noddi_mdp} space={ent.get('space')} -> {chosen}"
    )
    return chosen


def find_parc_files_t1w(parc_dir: str, subject: str) -> list[str]:
    return glob(f"{parc_dir}/sub-{subject}/anat/sub-{subject}_space-T1w_desc-*_dseg.nii.gz")


def parc_file_t1w(parc_dir: str, subject: str, parc_desc: str) -> str:
    return os.path.join(parc_dir, f"sub-{subject}", "anat", f"sub-{subject}_space-T1w_desc-{parc_desc}_dseg.nii.gz")


def _read_label_tsv(templates_dir: str, parc: str) -> str | None:
    # your template TSV copies land in /parc root
    if parc in ["wmparc", "aparcaseg"]:
        tsv = os.path.join(templates_dir, "desc-FreeSurferAll_dseg.tsv")
    else:
        tsv = os.path.join(templates_dir, f"atlas-{parc}_dseg.tsv")
    return tsv if os.path.exists(tsv) else None


def _qsiprep_t1w_ref(qsiprep_dir: str, subject: str) -> nib.Nifti1Image:
    p = os.path.join(qsiprep_dir, f"sub-{subject}", "anat", f"sub-{subject}_desc-preproc_T1w.nii")
    if not os.path.exists(p):
        raise FileNotFoundError(f"Missing QSIPrep preproc T1w: {p}")
    return _load_img(p)


def _qsiprep_dseg(qsiprep_dir: str, subject: str) -> str | None:
    p = os.path.join(qsiprep_dir, f"sub-{subject}", "anat", f"sub-{subject}_dseg.nii.gz")
    return p if os.path.exists(p) else None


# -----------------------------
# Core compute (ALL on QSIPrep preproc T1w grid)
# -----------------------------

def extract_noddi_parc_results(
    subject: str,
    session: str | None,
    parc_file: str,
    parc_tsv: str | None,
    noddi_dir: str,
    qsiprep_dir: str,
    tsv_out: str,
    icvf_max_threshold: float,
):
    # Truth grid
    t1w_img = _qsiprep_t1w_ref(qsiprep_dir, subject)

    parc_img_native = _load_img(parc_file)
    parc_t1w = resample_to_img(parc_img_native, t1w_img, interpolation="nearest")
    parc_t1w = _force_xform_like(parc_t1w, t1w_img)

    # ICVF on truth grid (for coverage + masking)
    icvf_path = noddi_filename(noddi_dir, subject, session, "icvf")
    icvf_img_native = _load_img(icvf_path)
    icvf_t1w = resample_to_img(icvf_img_native, t1w_img, interpolation="continuous")
    icvf_t1w = _force_xform_like(icvf_t1w, t1w_img)

    # voxel volume
    pixdim = parc_t1w.header.get_zooms()[:3]
    voxel_size = float(pixdim[0] * pixdim[1] * pixdim[2])

    full_df = _parcel_counts(parc_t1w).rename(columns={"n_vx": "n_vx_full"})
    full_df["size_full"] = full_df["n_vx_full"] * voxel_size
    results = full_df.copy()

    # label names
    if parc_tsv:
        labeldf = pd.read_csv(parc_tsv, sep="\t")
        if not {"index", "name"}.issubset(labeldf.columns):
            raise ValueError(f"Label TSV missing required columns {{index,name}}: {parc_tsv}")
        labeldf = labeldf[["index", "name"]].copy()
        labeldf["index"] = labeldf["index"].astype(int)
        labeldf = labeldf.drop_duplicates("index").set_index("index")
        results = results.set_index("index").join(labeldf, how="left").reset_index()
    else:
        results["name"] = np.nan

    # coverage mask from ICVF (on truth grid)
    good_mask = math_img(f"(img1 > 0) * (img1 < {float(icvf_max_threshold)})", img1=icvf_t1w)
    good_mask = _force_xform_like(good_mask, t1w_img)

    good_parc = math_img("img1 * img2", img1=good_mask, img2=parc_t1w)
    good_parc = _force_xform_like(good_parc, t1w_img)

    masked_df = _parcel_counts(good_parc).rename(columns={"n_vx": "n_vx_masked"})
    results = results.merge(masked_df, on="index", how="left")
    results["n_vx_masked"] = results["n_vx_masked"].fillna(0).astype(int)
    results["coverage"] = np.where(
        results["n_vx_full"] > 0,
        results["n_vx_masked"] / results["n_vx_full"],
        np.nan
    )

    # stats per metric (resample each NODDI metric to truth grid)
    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_path = noddi_filename(noddi_dir, subject, session, noddi_mdp)
        noddi_img_native = _load_img(noddi_path)
        noddi_t1w = resample_to_img(noddi_img_native, t1w_img, interpolation="continuous")
        noddi_t1w = _force_xform_like(noddi_t1w, t1w_img)

        # Use the ICVF-derived good mask for ICVF stats (and optional masking can be applied to others too if you want)
        if noddi_mdp == "icvf":
            parc_for_stats = good_parc
        else:
            parc_for_stats = parc_t1w

        # mean
        m_mean = NiftiLabelsMasker(labels_img=parc_for_stats, strategy="mean")
        mean_vals = m_mean.fit_transform(noddi_t1w).ravel()
        s_mean = _masker_to_series(m_mean, mean_vals)
        results[f"{noddi_mdp}_mean"] = results["index"].map(s_mean)

        # stdev
        m_std = NiftiLabelsMasker(labels_img=parc_for_stats, strategy="standard_deviation")
        std_vals = m_std.fit_transform(noddi_t1w).ravel()
        s_std = _masker_to_series(m_std, std_vals)
        results[f"{noddi_mdp}_stdev"] = results["index"].map(s_std)

    # tissue probs from qsiprep dseg -> resample to truth grid
    qsiprep_dseg_path = _qsiprep_dseg(qsiprep_dir, subject)
    if qsiprep_dseg_path:
        tissue_native = _load_img(qsiprep_dseg_path)
        tissue_t1w = resample_to_img(tissue_native, t1w_img, interpolation="nearest")
        tissue_t1w = _force_xform_like(tissue_t1w, t1w_img)

        dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}
        for tissue, val in dseg_labels.items():
            tissue_mask = math_img(f"img1 == {int(val)}", img1=tissue_t1w)
            tissue_mask = _force_xform_like(tissue_mask, t1w_img)

            tmasker = NiftiLabelsMasker(labels_img=parc_t1w, strategy="mean")
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

    os.makedirs(os.path.dirname(tsv_out), exist_ok=True)
    results.to_csv(tsv_out, index=False, sep="\t")
    return results


# -----------------------------
# QA Figures (ALL on QSIPrep preproc T1w grid)
# -----------------------------

def make_dseg_qsi_qa_image(subject, session, noddi_mdp, noddi_dir, qsiprep_dir, parc_file, parc_name, out_png):
    t1w_img = _qsiprep_t1w_ref(qsiprep_dir, subject)

    parc_img = _load_img(parc_file)
    parc_t1w = resample_to_img(parc_img, t1w_img, interpolation="nearest")
    parc_t1w = _force_xform_like(parc_t1w, t1w_img)

    noddi_file = noddi_filename(noddi_dir, subject, session, noddi_mdp)
    noddi_img = _load_img(noddi_file)
    noddi_t1w = resample_to_img(noddi_img, t1w_img, interpolation="continuous")
    noddi_t1w = _force_xform_like(noddi_t1w, t1w_img)

    roi_data = np.asarray(parc_t1w.get_fdata(), dtype=np.int16)
    roi_on_bg = new_img_like(noddi_t1w, roi_data, copy_header=True)

    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    return nilearn.plotting.plot_roi(
        roi_img=roi_on_bg,
        bg_img=noddi_t1w,
        alpha=0.4,
        display_mode="mosaic",
        title=f"sub-{subject} {parc_name} on noddi {noddi_mdp} (QSIPrep T1w grid)",
        output_file=out_png,
    )


def make_noddi_3tissues_plot(subject, session, noddi_dir, qsiprep_dir, out_png, icvf_thresh):
    t1w_img = _qsiprep_t1w_ref(qsiprep_dir, subject)
    qsiprep_dseg_path = _qsiprep_dseg(qsiprep_dir, subject)
    if not qsiprep_dseg_path:
        return

    # Tissue on truth grid
    tissue_native = _load_img(qsiprep_dseg_path)
    tissue_t1w = resample_to_img(tissue_native, t1w_img, interpolation="nearest")
    tissue_t1w = _force_xform_like(tissue_t1w, t1w_img)

    # ICVF on truth grid -> mask (used for all metrics)
    icvf_path = noddi_filename(noddi_dir, subject, session, "icvf")
    icvf_native = _load_img(icvf_path)
    icvf_t1w = resample_to_img(icvf_native, t1w_img, interpolation="continuous")
    icvf_t1w = _force_xform_like(icvf_t1w, t1w_img)

    good = math_img(f"(img1 > 0) * (img1 < {float(icvf_thresh)})", img1=icvf_t1w)
    good = _force_xform_like(good, t1w_img)

    dseg_labels = {"CSF": 1, "GM": 2, "WM": 3}
    df0 = []

    for noddi_mdp in ["icvf", "od", "isovf"]:
        noddi_path = noddi_filename(noddi_dir, subject, session, noddi_mdp)
        noddi_native = _load_img(noddi_path)
        noddi_t1w = resample_to_img(noddi_native, t1w_img, interpolation="continuous")
        noddi_t1w = _force_xform_like(noddi_t1w, t1w_img)

        for tissue, val in dseg_labels.items():
            # (tissue == val) * good * noddi
            tm = math_img(f"(img1 == {int(val)}) * img2 * img3", img1=tissue_t1w, img2=good, img3=noddi_t1w)
            tm = _force_xform_like(tm, t1w_img)
            flat = np.asarray(tm.get_fdata()).ravel()
            flat = flat[flat > 0]
            if flat.size == 0:
                continue
            df0.append(pd.DataFrame({"tissue": tissue, "noddi": noddi_mdp, "value": flat}))

    if not df0:
        return

    df = pd.concat(df0, axis=0, ignore_index=True)
    g = sns.FacetGrid(df, col="noddi", hue="tissue")
    g.map_dataframe(sns.kdeplot, x="value", clip=[0, 1])
    g.add_legend()
    g.fig.subplots_adjust(top=0.88)
    g.fig.suptitle(f"sub-{subject} ses-{session} NODDI values by tissue (QSIPrep T1w grid)")

    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    g.savefig(out_png)


# -----------------------------
# Main
# -----------------------------

def main():
    args = docopt(__doc__)
    logging.basicConfig(level=logging.DEBUG if args["--debug"] else logging.WARNING)

    parc_dir = args["--parc-dir"]
    qsiprep_dir = args["--qsiprep-dir"]
    noddi_dir = args["--amico-noddi-dir"]

    subject = str(args["--subject"]).replace("sub-", "")
    session = args["--session"]
    icvf_thresh = float(args["--icvf-thresh"])
    only_parc = args["--parcellation"]

    # parcellations
    if only_parc:
        parc_list = [only_parc]
        pf = parc_file_t1w(parc_dir, subject, only_parc)
        if not os.path.exists(pf):
            raise FileNotFoundError(f"Missing parcellation: {pf}")
    else:
        parc_files = find_parc_files_t1w(parc_dir, subject)
        if not parc_files:
            raise FileNotFoundError(f"No T1w parcellations found in {parc_dir}/sub-{subject}/anat")
        parc_list = sorted({parse_file_entities(pf)["desc"] for pf in parc_files})

    # sessions
    if session:
        session = str(session).replace("ses-", "")
        sessions = [session]
    else:
        # infer sessions from files
        blist = glob(f"{noddi_dir}/sub-{subject}/*/dwi/*.nii*")
        ses_list = [parse_file_entities(bf).get("session") for bf in blist]
        sessions = sorted({s for s in ses_list if s is not None}) or [None]

    templates_dir = parc_dir  # you copy TSVs here in SLURM

    for ses in sessions:
        fig_dir = os.path.join(parc_dir, f"sub-{subject}", "figures")
        os.makedirs(fig_dir, exist_ok=True)

        density_out = os.path.join(
            fig_dir,
            f"sub-{subject}_ses-{ses}_desc-dsegtissue_model-noddi_density.png" if ses else
            f"sub-{subject}_desc-dsegtissue_model-noddi_density.png"
        )
        make_noddi_3tissues_plot(subject, ses, noddi_dir, qsiprep_dir, density_out, icvf_thresh)

        for parc in parc_list:
            parc_path = parc_file_t1w(parc_dir, subject, parc)
            label_tsv = _read_label_tsv(templates_dir, parc)

            # QA overlays
            for noddi_mdp in ["od", "icvf"]:
                qa_out = os.path.join(
                    fig_dir,
                    f"sub-{subject}_ses-{ses}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png" if ses else
                    f"sub-{subject}_desc-{parc}_model-noddi_mdp-{noddi_mdp}_qa.png"
                )
                make_dseg_qsi_qa_image(subject, ses, noddi_mdp, noddi_dir, qsiprep_dir, parc_path, parc, qa_out)

            # TSV out
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
                parc_tsv=label_tsv,
                noddi_dir=noddi_dir,
                qsiprep_dir=qsiprep_dir,
                tsv_out=tsv_out,
                icvf_max_threshold=icvf_thresh,
            )


if __name__ == "__main__":
    main()
