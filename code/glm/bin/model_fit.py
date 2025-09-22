import json
import logging
import os
import re
from functools import partial
from pathlib import Path
from warnings import warn

import nibabel as nb
import numpy as np
import pandas as pd

from .bids_util import LoadBidsModel
from .design_matrix import FirstLevelDesignMatrix
from .run_match import BoldEventsMatch
from .visualize import load_data, plot_dscalar

# Configure module logger
logger = logging.getLogger("bin.model_fit")


class FirstLevelModelFit(BoldEventsMatch, FirstLevelDesignMatrix):
    """
    A class to handle BIDS directory inputs for GLM analysis.

    This class stores essential information about a BIDS dataset and its
    derivatives, including the task, participant, session, space, and density
    parameters, and a BIDS Stat Model dictionary which are used to fit a run-level GLM for each session from fmriprep derivative.

    Attributes:
        bids_dir (str): Path to the root BIDS dataset.
        derivatives_dir (str): Path to the derivatives directory containing preprocessed data.
        task_label (str): The task label corresponding to the fMRI task being analyzed.
        participant_label (str): Subject ID (e.g., "CMHWM01").
        space_label (str): The anatomical or functional space of the images (e.g., "MNI152NLin2009cAsym", "fsLR").
        session (str): Session identifier (e.g., "01").
        dense (str): Numbers of vertices on CIFTI surfaces (e.g., 91k).
        specs (dict): A dictionary represent BIDS Stat Model
    """

    def __init__(
        self,
        bids_dir,
        derivatives_dir,
        participant_label,
        task_label,
        session,
        space_label,
        dense,
        model_spec,
        outputdir=None,
    ):
        BoldEventsMatch.__init__(
            self,
            bids_dir,
            derivatives_dir,
            participant_label,
            task_label,
            session,
            space_label,
            dense,
        )
        FirstLevelDesignMatrix.__init__(
            self,
            bids_dir,
            derivatives_dir,
            participant_label,
            task_label,
            session,
            space_label,
            dense,
            model_spec,
        )
        # self.specs = LoadBidsModel(model_spec)._ensure_model()
        self.outputdir = outputdir

    def dscalar_from_cifti(self, img, data, name):

        # Clear old CIFTI-2 extensions from NIfTI header and set intent
        nifti_header = img.nifti_header.copy()
        nifti_header.extensions.clear()
        nifti_header.set_intent("ConnDenseScalar")

        # Create CIFTI-2 header
        scalar_axis = nb.cifti2.ScalarAxis(np.atleast_1d(name))
        axes = [
            nb.cifti2.cifti2_axes.from_index_mapping(mim) for mim in img.header.matrix
        ]
        if len(axes) != 2:
            raise ValueError(
                f"Can't generate dscalar CIFTI-2 from header with axes {axes}"
            )
        header = nb.cifti2.cifti2_axes.to_header(
            axis if isinstance(axis, nb.cifti2.BrainModelAxis) else scalar_axis
            for axis in axes
        )

        new_img = nb.Cifti2Image(
            data.reshape(header.matrix.get_data_shape()),
            header=header,
            nifti_header=nifti_header,
        )
        return new_img

    def _get_voxelwise_stat(self, labels, results, stat):
        voxelwise_attribute = np.zeros((1, len(labels)))

        for label_ in results:
            label_mask = labels == label_
            voxelwise_attribute[:, label_mask] = getattr(results[label_], stat)

        return voxelwise_attribute

    def _iter_valid_runs(self):
        """Generator that yields entry of the match dictionary."""
        for entry in self.match_runs:
            yield entry

    def _get_run_level_contrasts(self, dm, model_spec):
        out_contrasts = []
        for node in model_spec["Nodes"]:
            if node["Level"] == "Run":
                for contrast_info in node["Contrasts"]:
                    conds = contrast_info["ConditionList"]
                    # logger.info(f"Contrast info: {contrast_info}")
                    in_weights = np.atleast_2d(contrast_info["Weights"])
                    # logger.info(f"Weights shape: {in_weights.shape[0]}")
                    missing = len(conds) != in_weights.shape[1] or any(
                        cond not in dm.columns for cond in conds
                    )
                    if missing:
                        continue
                    weights = np.zeros(
                        (in_weights.shape[0], len(dm.columns)), dtype=in_weights.dtype
                    )
                    # Find indices of input conditions in all_regressors list
                    sorter = np.argsort(dm.columns)
                    indices = sorter[np.searchsorted(dm.columns, conds, sorter=sorter)]
                    weights[:, indices] = in_weights

                    out_contrasts.append(
                        (
                            contrast_info["Name"],
                            weights,
                            contrast_info["Test"],
                        )
                    )
        return out_contrasts

    def _format_filename(
        self,
        prefix="",
        suffix="",
        participant_label=None,
        task_label=None,
        ses=None,
        run=None,
        contrast=None,
        stat=None,
        ext="nii",
    ):
        parts = []
        if participant_label:
            parts.append(f"sub-{participant_label}")
        if ses and ses != None:
            parts.append(f"ses-{ses}")
        if task_label:
            parts.append(f"task-{task_label}")
        if run:
            parts.append(f"run-{run}")
        if contrast:
            parts.append(f"contrast-{contrast}")
        if stat:
            parts.append(f"stat-{stat}")
        fname = "_".join(parts)
        return f"{prefix}{fname}{suffix}.{ext}"

    def process_and_fit_valid_run(self):
        from nilearn.glm import compute_contrast
        from nilearn.glm import first_level as level1
        from nilearn.plotting import plot_contrast_matrix, plot_design_matrix

        all_effect_maps = []
        all_variance_maps = []

        for entry in self._iter_valid_runs():
            ses = entry["session"]
            task = entry["task"]
            run = entry["run"]

            ses_str = f"| ses-{ses} " if ses else ""
            run_str = f"| run-{run}" if run else ""
            task_str = f"| task-{task} "
            logger.info(
                f"Generating design matrix for: {self.participant_label} {ses_str}{task_str}{run_str}"
            )

            dm = self.get_design_matrix(run, self.specs)
            logger.info(f"Columns of the convolved design matrix: {dm.columns}")
            logger.info(f"{'='*40}")
            sub_run_imgs, _, _ = self.get_data_from_bids(run)
            new_cifti_img, _, _ = self.drop_non_steady_scans(sub_run_imgs)
            is_cifti = isinstance(new_cifti_img, nb.Cifti2Image)
            if is_cifti:
                # Set up output directory
                if self.outputdir is not None:
                    self.outdir = Path(self.outputdir)
                else:
                    self.outdir = Path(self.derivatives_dir).parent

                glm_dir = self.outdir / "glm" / f"sub-{self.participant_label}"
                glm_dir.mkdir(exist_ok=True, parents=True)
                # fname_fmt = os.path.join(
                #     glm_dir,
                #     "sub-{}_ses-{}_task-{}_run-{}_contrast-{}_stat-{}_statmap.dscalar.nii",
                # ).format
                # modname_fmt = os.path.join(
                #     glm_dir, "sub-{}_ses-{}_task-{}_run-{}_stat-{}_statmap.dscalar.nii"
                # ).format

                logger.info(
                    f"Fitting Model for subject: {self.participant_label} {ses_str}{task_str}{run_str}"
                )
                logger.info(f"{'='*40}")
                labels, estimates = level1.run_glm(
                    new_cifti_img.get_fdata(dtype="f4"), dm.values
                )

                model_attr = {
                    "r_square": self.dscalar_from_cifti(
                        new_cifti_img,
                        self._get_voxelwise_stat(labels, estimates, "r_square"),
                        "r_square",
                    ),
                    "log_likelihood": self.dscalar_from_cifti(
                        new_cifti_img,
                        self._get_voxelwise_stat(labels, estimates, "logL"),
                        "log_likelihood",
                    ),
                    "mean_square_error": self.dscalar_from_cifti(
                        new_cifti_img,
                        self._get_voxelwise_stat(labels, estimates, "MSE"),
                        "mean_square_error",
                    ),
                }
            # save design matrix
            fname_dm = os.path.join(
                glm_dir,
                self._format_filename(
                    participant_label=self.participant_label,
                    ses=ses,
                    task_label=task,
                    run=run,
                    stat="design",
                    ext="tsv",
                ),
            )
            fname_dm_fig = os.path.join(
                glm_dir,
                self._format_filename(
                    participant_label=self.participant_label,
                    ses=ses,
                    task_label=task,
                    run=run,
                    stat="design",
                    ext="svg",
                ),
            )
            logger.info(f"Saving the {fname_dm}")
            dm.to_csv(fname_dm, index=False)
            logger.info(f"Saving the {fname_dm_fig}")
            plot_design_matrix(dm, output_file=fname_dm_fig)

            # Save model level images
            model_metadata = []

            for attr, img in model_attr.items():
                model_metadata.append({"stat": attr})
                fname = os.path.join(
                    glm_dir,
                    self._format_filename(
                        participant_label=self.participant_label,
                        ses=ses,
                        task_label=task,
                        run=run,
                        stat=attr,
                        ext="dscalar.nii",
                    ),
                )
                logger.info(f"Saving Model outputs: {fname}")
                img.to_filename(fname)

            contrasts = self._get_run_level_contrasts(dm, self.specs)
            effect_maps = []
            variance_maps = []
            stat_maps = []
            zscore_maps = []
            pvalue_maps = []
            for name, weights, contrast_test in contrasts:
                fname_contrast = os.path.join(
                    glm_dir,
                    self._format_filename(
                        participant_label=self.participant_label,
                        ses=ses,
                        task_label=task,
                        run=run,
                        contrast=name,
                        stat=contrast_test,
                        ext="svg",
                    ),
                )
                # fname_contrast = os.path.join(
                #     glm_dir,
                #     f"{self.participant_label}_ses-{ses}_task-{self.task_label}_run-{run}_contrast-{name}_stat-{contrast_test}.svg",
                # )
                plot_contrast_matrix(weights, dm, output_file=fname_contrast)
                logger.info(f"\n{'='*40}")
                logger.info(
                    f"Computing contrast for: {self.participant_label} {ses_str}{task_str}{run_str}"
                )
                logger.info(f"Contrast name: {name}")
                logger.info(f"Contrast weights: {weights}")
                logger.info(f"Contrast type: {contrast_test}")
                contrast = compute_contrast(
                    labels, estimates, weights, stat_type=contrast_test
                )
                maps = {
                    map_type: self.dscalar_from_cifti(
                        new_cifti_img, getattr(contrast, map_type)(), map_type
                    )
                    for map_type in [
                        "z_score",
                        "stat",
                        "p_value",
                        "effect_size",
                        "effect_variance",
                    ]
                }
                for map_type, map_list in (
                    ("effect_size", effect_maps),
                    ("effect_variance", variance_maps),
                    ("z_score", zscore_maps),
                    ("p_value", pvalue_maps),
                    ("stat", stat_maps),
                ):
                    fname = os.path.join(
                        glm_dir,
                        self._format_filename(
                            participant_label=self.participant_label,
                            ses=ses,
                            task_label=task,
                            run=run,
                            contrast=name,
                            stat=contrast_test if map_type == "stat" else map_type,
                            ext="dscalar.nii",
                        ),
                    )
                    logger.info(f"Saving Regressor output: {fname}")
                    map_list.append(fname)
                    maps[map_type].to_filename(fname)
            # accumulate effect_maps for run
            all_effect_maps.extend(effect_maps)
            all_variance_maps.extend(variance_maps)

        return all_effect_maps, all_variance_maps

    def compute_fix_effect(self, effect_maps, variance_maps):
        from collections import defaultdict

        from nilearn.glm.contrasts import _compute_fixed_effects_params

        if self.outputdir is not None:
            self.outdir = Path(self.outputdir)
        else:
            self.outdir = Path(self.derivatives_dir).parent

        glm_dir = self.outdir / "glm" / f"sub-{self.participant_label}"
        glm_dir.mkdir(exist_ok=True, parents=True)

        # Prepare DataFrame
        rows = []
        for eff, var in zip(effect_maps, variance_maps):
            m = re.search(r"ses-([a-zA-Z0-9]+).*contrast-([a-zA-Z0-9]+)", eff)
            if m:
                ses, contrast = m.groups()
                rows.append(
                    {
                        "session": ses,
                        "contrast": contrast,
                        "effect_path": eff,
                        "var_path": var,
                    }
                )
            else:
                # fallback if session is missing, assume single session
                contrast = eff.split("contrast-")[1].split("_stat")[0]
                rows.append(
                    {
                        "session": None,
                        "contrast": contrast,
                        "effect_path": eff,
                        "var_path": var,
                    }
                )

        df = pd.DataFrame(rows)

        # Determine grouping columns
        group_cols = (
            ["session", "contrast"] if df["session"].notna().all() else ["contrast"]
        )

        for key, group in df.groupby(group_cols):
            if isinstance(key, tuple) and len(key) > 1:
                session, contrast = key
            else:
                session, contrast = None, key[0]

            contrast_imgs = group["effect_path"].tolist()
            variance_imgs = group["var_path"].tolist()
            n_runs = len(contrast_imgs)
            dofs = [100] * n_runs

            if n_runs < 2:
                logger.info(
                    f"Skip computing the fix-effects for {contrast} session {session}: only {n_runs} run available"
                )
                continue

            # Compute fixed effects
            ffx_cont, ffx_var, ffx_t, ffx_z_score = _compute_fixed_effects_params(
                np.squeeze([nb.load(f).get_fdata(dtype="f4") for f in contrast_imgs]),
                np.squeeze([nb.load(f).get_fdata(dtype="f4") for f in variance_imgs]),
                precision_weighted=False,
                dofs=dofs,
            )

            # Use first run as template
            img = nb.load(contrast_imgs[0])
            maps = {
                "fixed_effect_size": self.dscalar_from_cifti(
                    img, ffx_cont, "fixed_effect_size"
                ),
                "fixed_effect_variance": self.dscalar_from_cifti(
                    img, ffx_var, "fixed_effect_variance"
                ),
                "fixed_effect_stat": self.dscalar_from_cifti(
                    img, ffx_t, "fixed_effect_stat"
                ),
                "fixed_effect_z_score": self.dscalar_from_cifti(
                    img, ffx_z_score, "fixed_effect_z_score"
                ),
            }

            # Save maps
            task_label = (
                self.task_label[0]
                if isinstance(self.task_label, list)
                else self.task_label
            )
            for map_type, cifti_img in maps.items():
                stat_label = "fixed_t" if map_type == "fixed_stat" else map_type
                fname = os.path.join(
                    glm_dir,
                    self._format_filename(
                        participant_label=self.participant_label,
                        ses=session,
                        task_label=task_label,
                        contrast=contrast,
                        stat=stat_label,
                        ext="dscalar.nii",
                    ),
                )
                logger.info(f"Saving {map_type} to: {fname}")
                maps[map_type].to_filename(fname)
                logger.info(f"Plotting the computed fix-effect contrast: {map_type}")
                outname = fname.replace("dscalar.nii", "png")
                if isinstance(maps[map_type], nb.Cifti2Image):
                    plot_dscalar(maps[map_type], colorbar=False, output_file=outname)
