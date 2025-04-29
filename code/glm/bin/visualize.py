import os

import nibabel as nb
import numpy as np
from nilearn import plotting as nlp
from nipype.utils.filemanip import fname_presuffix, split_filename


def load_data(fname):
    _, _, ext = split_filename(fname)
    if ext == ".tsv":
        return pd.read_table(fname, index_col=0)
    elif ext in (".nii", ".nii.gz", ".gii"):
        return nb.load(fname)
    raise ValueError("Unknown file type!")


def plot_dscalar(
    img,
    colorbar=True,
    # plot_abs=False,
    vmax=None,
    threshold=None,
    cmap="roy_big_bl",
    output_file=None,
):
    import matplotlib as mpl
    from matplotlib import pyplot as plt

    subcort, ltexture, rtexture = decompose_dscalar(img)

    if not vmax:
        vmax_r = np.percentile(rtexture, 99)
        vmax_l = np.percentile(ltexture, 99)
        vmax = (vmax_r + vmax_l) / 2

    fig = plt.figure(figsize=(11, 9))
    ax1 = plt.subplot2grid((2, 2), (0, 0), projection="3d")
    ax2 = plt.subplot2grid((2, 2), (0, 1), projection="3d")
    ax3 = plt.subplot2grid((2, 2), (1, 0), projection="3d")
    ax4 = plt.subplot2grid((2, 2), (1, 1), projection="3d")
    # ax5 = plt.subplot2grid((3, 2), (2, 0), colspan=2)
    module_dir = os.path.dirname(os.path.abspath(__file__))
    template_dir = os.path.join(module_dir, "..", "templates")
    surf_fmt = os.path.join(
        template_dir, "tpl-conte69_hemi-{hemi}_space-fsLR_den-32k_inflated.surf.gii"
    ).format
    lsurf = nb.load(surf_fmt(hemi="L")).agg_data()
    rsurf = nb.load(surf_fmt(hemi="R")).agg_data()
    nlp.plot_surf_stat_map(
        lsurf,
        ltexture,
        vmax=vmax,
        cmap=cmap,
        view="lateral",
        axes=ax1,
    )
    nlp.plot_surf_stat_map(
        rsurf,
        rtexture,
        vmax=vmax,
        cmap=cmap,
        view="medial",
        axes=ax2,
    )
    nlp.plot_surf_stat_map(
        lsurf,
        ltexture,
        vmax=vmax,
        cmap=cmap,
        view="medial",
        axes=ax3,
    )
    nlp.plot_surf_stat_map(
        rsurf,
        rtexture,
        vmax=vmax,
        cmap=cmap,
        view="lateral",
        axes=ax4,
    )

    if colorbar:
        data = img.get_fdata(dtype=np.float32)
        if vmax is None:
            vmax = max(-data.min(), data.max())
        norm = mpl.colors.Normalize(vmin=-vmax if data.min() < 0 else 0, vmax=vmax)
        sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
        fig.colorbar(sm, ax=fig.axes, location="right", aspect=50)
    if output_file:
        fig.savefig(output_file)
        plt.close(fig)


def decompose_dscalar(img):
    data = img.get_fdata(dtype=np.float32)
    ax = img.header.get_axis(1)
    vol = np.zeros(ax.volume_shape, dtype=np.float32)
    vox_indices = tuple(ax.voxel[ax.volume_mask].T)
    vol[vox_indices] = data[:, ax.volume_mask]
    subcort = nb.Nifti1Image(vol, ax.affine)

    surfs = {}
    for name, indices, brainmodel in ax.iter_structures():
        if not name.startswith("CIFTI_STRUCTURE_CORTEX_"):
            continue
        hemi = name.split("_")[3].lower()
        texture = np.zeros(brainmodel.vertex.max() + 1, dtype=np.float32)
        texture[brainmodel.vertex] = data[:, indices]
        surfs[hemi] = texture

    return subcort, surfs["left"], surfs["right"]
