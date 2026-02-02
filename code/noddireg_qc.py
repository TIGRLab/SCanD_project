#!/usr/bin/env python3

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
    base = os.path.basename(pscalar_path)
    m = re.search(r"(sub-[A-Za-z0-9]+)", base)
    if not m:
        raise ValueError(f"Cannot infer subject ID from filename: {base}")
    return m.group(1)


def plot_view(surf, data, hemi, view, out_png):
    plotting.plot_surf_stat_map(
        surf_mesh=surf,
        stat_map=data,
        hemi=hemi,
        view=view,
        cmap="viridis",
        colorbar=True,
        output_file=out_png,
    )


def main():
    ap = argparse.ArgumentParser("QC: pscalar → 2x2 surface PNG")
    ap.add_argument("--pscalar", required=True, help="Input .pscalar.nii")
    ap.add_argument("--dlabel", required=True, help="Atlas dlabel.nii (fsLR 91k)")
    ap.add_argument("--surf-dir", required=True, help="fsaverage_LR32k surface directory")
    ap.add_argument("--out", required=True, help="Output PNG")
    args = ap.parse_args()

    subj = infer_subject_id(args.pscalar)

    # -----------------------------
    # Load surfaces
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
    parcel_vals = np.asarray(
        nib.load(args.pscalar).dataobj
    ).squeeze()

    # -----------------------------
    # Load labels from dlabel
    # -----------------------------
    labels = np.asarray(
        nib.load(args.dlabel).get_fdata(),
        dtype=np.int64
    ).ravel()

    if labels.size < 2 * N_VERT:
        raise ValueError(
            f"dlabel too small: {labels.size} < {2 * N_VERT}"
        )

    # Cortex only (fsLR order)
    lh_labels = labels[:N_VERT]
    rh_labels = labels[N_VERT:2 * N_VERT]

    # -----------------------------
    # Expand parcels → vertices
    # -----------------------------
    lh_data = np.full(N_VERT, np.nan, dtype=np.float32)
    rh_data = np.full(N_VERT, np.nan, dtype=np.float32)

    max_label = int(max(lh_labels.max(), rh_labels.max()))
    fill_to = min(len(parcel_vals), max_label)

    for idx in range(1, fill_to + 1):
        v = parcel_vals[idx - 1]

        # Skip NaNs explicitly
        if not np.isfinite(v):
            continue

        lh_data[lh_labels == idx] = v
        rh_data[rh_labels == idx] = v

    # -----------------------------
    # Render 4 views
    # -----------------------------
    tmp = {
        "lh_lat": "tmp_lh_lateral.png",
        "lh_med": "tmp_lh_medial.png",
        "rh_lat": "tmp_rh_lateral.png",
        "rh_med": "tmp_rh_medial.png",
    }

    plot_view(lh_surf, lh_data, "left",  "lateral", tmp["lh_lat"])
    plot_view(lh_surf, lh_data, "left",  "medial",  tmp["lh_med"])
    plot_view(rh_surf, rh_data, "right", "lateral", tmp["rh_lat"])
    plot_view(rh_surf, rh_data, "right", "medial",  tmp["rh_med"])

    # -----------------------------
    # Stitch into 2x2 image
    # -----------------------------
    imgs = [Image.open(tmp[k]).convert("RGB") for k in tmp]
    w, h = imgs[0].size

    out = Image.new("RGB", (2 * w, 2 * h), (255, 255, 255))
    out.paste(imgs[0], (0, 0))
    out.paste(imgs[1], (w, 0))
    out.paste(imgs[2], (0, h))
    out.paste(imgs[3], (w, h))
    out.save(args.out)

    # Cleanup
    for f in tmp.values():
        try:
            os.remove(f)
        except OSError:
            pass

    print(f"[QC] wrote {args.out}")


if __name__ == "__main__":
    main()
