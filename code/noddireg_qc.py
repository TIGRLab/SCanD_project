#!/usr/bin/env python3
"""
qc.py

Create a 2x2 surface QC PNG (LH lat/med, RH lat/med) from a parcellated CIFTI pscalar
using a matching fsLR 91k dlabel for parcel->vertex expansion.

Designed to run inside Singularity with binds like:
  -B ${DWI_OUT_DIR}:/data
  -B ${TEMPLATES_DIR}:/templates
  -B ${SURF_DIR_SUBJ}:/surf

Example:
python3 /code/qc.py \
  --pscalar /data/sub-ZHP0016_ses-01_od_mean.pscalar.nii \
  --dlabel  /templates/tpl-fsLR_res-91k_atlas-4S1056Parcels_dseg.dlabel.nii \
  --surf-dir /surf \
  --out /data/sub-ZHP0016_ses-01_od_mean_qc.png
"""

import argparse
import os
import re

import numpy as np
import nibabel as nib
from nilearn import plotting
from PIL import Image
import matplotlib

matplotlib.use("Agg") 

N_VERT = 32492 


def infer_subject_id(pscalar_path: str) -> str:
    """Extract 'sub-XXXX' from filename."""
    base = os.path.basename(pscalar_path)
    m = re.search(r"(sub-[A-Za-z0-9]+)", base)
    if not m:
        raise ValueError(f"Cannot infer subject ID from filename: {base}")
    return m.group(1)


def plot_view(surf, data, hemi, view, out_png):
    """Render one surface view to a PNG file."""
    plotting.plot_surf_stat_map(
        surf_mesh=surf,
        stat_map=data,
        hemi=hemi,
        view=view,
        cmap="viridis",
        colorbar=False,
        output_file=out_png,
    )


def main():
    ap = argparse.ArgumentParser(description="QC: pscalar -> 2x2 surface PNG")
    ap.add_argument("--pscalar", required=True, help="Input .pscalar.nii")
    ap.add_argument("--dlabel", required=True, help="Atlas dlabel.nii (fsLR 91k)")
    ap.add_argument("--surf-dir", required=True, help="fsaverage_LR32k surface directory")
    ap.add_argument("--out", required=True, help="Output PNG")
    args = ap.parse_args()

    subj = infer_subject_id(args.pscalar)

    # -----------------------------
    # Surfaces
    # -----------------------------
    lh_surf = os.path.join(args.surf_dir, f"{subj}.L.midthickness.32k_fs_LR.surf.gii")
    rh_surf = os.path.join(args.surf_dir, f"{subj}.R.midthickness.32k_fs_LR.surf.gii")

    if not os.path.exists(lh_surf):
        raise FileNotFoundError(f"Missing LH surface: {lh_surf}")
    if not os.path.exists(rh_surf):
        raise FileNotFoundError(f"Missing RH surface: {rh_surf}")

    # -----------------------------
    # Load parcel values (pscalar)
    # -----------------------------
    parcel_vals = np.asarray(nib.load(args.pscalar).dataobj).squeeze()

    # -----------------------------
    # Load labels from dlabel (fsLR 91k)
    # First 32k = LH cortex, next 32k = RH cortex
    # -----------------------------
    labels = np.asarray(nib.load(args.dlabel).get_fdata(), dtype=np.int64).ravel()
    if labels.size < 2 * N_VERT:
        raise ValueError(f"dlabel too small: {labels.size} < {2*N_VERT}")

    lh_labels = labels[:N_VERT]
    rh_labels = labels[N_VERT:2 * N_VERT]

    # -----------------------------
    # Expand parcels -> vertices
    # -----------------------------
    lh_data = np.zeros(N_VERT, dtype=np.float32)
    rh_data = np.zeros(N_VERT, dtype=np.float32)

    max_label = int(max(lh_labels.max(), rh_labels.max()))
    fill_to = min(len(parcel_vals), max_label)

    for idx in range(1, fill_to + 1):
        v = parcel_vals[idx - 1]
        if not np.isfinite(v):
            continue
        lh_data[lh_labels == idx] = v
        rh_data[rh_labels == idx] = v

    # -----------------------------
    # Render 4 views
    # -----------------------------
    out_dir = os.path.dirname(os.path.abspath(args.out)) or "."
    tmp = {
        "lh_lat": os.path.join(out_dir, "tmp_lh_lateral.png"),
        "lh_med": os.path.join(out_dir, "tmp_lh_medial.png"),
        "rh_lat": os.path.join(out_dir, "tmp_rh_lateral.png"),
        "rh_med": os.path.join(out_dir, "tmp_rh_medial.png"),
    }

    plot_view(lh_surf, lh_data, "left", "lateral", tmp["lh_lat"])
    plot_view(lh_surf, lh_data, "left", "medial",  tmp["lh_med"])
    plot_view(rh_surf, rh_data, "right", "lateral", tmp["rh_lat"])
    plot_view(rh_surf, rh_data, "right", "medial",  tmp["rh_med"])

    # Confirm files exist (clear error if nilearn failed to write)
    for k in ["lh_lat", "lh_med", "rh_lat", "rh_med"]:
        if not os.path.exists(tmp[k]):
            raise RuntimeError(f"Expected plot not created: {tmp[k]}")

    # -----------------------------
    # Stitch into 2x2
    # -----------------------------
    order = ["lh_lat", "lh_med", "rh_lat", "rh_med"]
    imgs = [Image.open(tmp[k]).convert("RGB") for k in order]
    w, h = imgs[0].size

    out_img = Image.new("RGB", (2 * w, 2 * h), (255, 255, 255))
    out_img.paste(imgs[0], (0, 0))
    out_img.paste(imgs[1], (w, 0))
    out_img.paste(imgs[2], (0, h))
    out_img.paste(imgs[3], (w, h))
    out_img.save(args.out)

    # Cleanup
    for f in tmp.values():
        try:
            os.remove(f)
        except OSError:
            pass

    print(f"[QC] wrote {args.out}")


if __name__ == "__main__":
    main()
