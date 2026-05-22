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
from .cifti_smooth import get_cifti_surf, wb_smooth
from .design_matrix import FirstLevelDesignMatrix
from .run_match import BoldEventsMatch
from .model_report import (
    build_fixed_effects_sidecar,
    build_run_level_sidecar,
    finalize_run_level_sidecar,
    update_run_level_sidecar,
    write_sidecar,
)
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
        model_spec (str): Path to a BIDS Stat Model json.
        outputdir (str): Path to the output directory.
        drop_duration (int): Number of seconds to discard from the start of the scan.
        fwhm (int): Smoothing kernel size in mm FWHM.
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
        drop_duration=None,
        fwhm=None,
        ciftify_dir=None
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
            drop_duration=drop_duration,
        )
        self.outputdir = outputdir
        self.fwhm = fwhm
        self.ciftify_dir = ciftify_dir

    def __repr__(self):
        return (
            f"FirstLevelModelFit("
            f"sub-{self.participant_label}, "
            f"ses-{self.session}, "
            f"task-{self.task_label}, "
            f"space-{self.space_label}, "
            f"den-{self.dense}, "
            f"fwhm={self.fwhm}, "
            f"matched_runs={[r['run'] for r in self.match_runs]})"
        )

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
        first = getattr(results[list(results.keys())[0]], stat)
        n_rows = first.shape[0] if np.ndim(first) > 1 else 1
        # voxelwise_attribute = np.zeros((1, len(labels)))
        voxelwise_attribute = np.zeros((n_rows, len(labels)), dtype="f4")

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
                    in_weights = np.atleast_2d(contrast_info["Weights"])
                    # missing = len(conds) != in_weights.shape[1] or any(
                    #     cond not in dm.columns for cond in conds
                    # )
                    # if missing:
                    #     continue
                    if len(conds) != in_weights.shape[1]:
                        raise ValueError(
                            f"Contrast '{contrast_info['Name']}': ConditionList has {len(conds)} "
                            f"conditions but Weights has {in_weights.shape[1]} columns."
                        )
                    missing_conds = [cond for cond in conds if cond not in dm.columns]
                    if missing_conds:
                        raise ValueError(
                            f"Contrast '{contrast_info['Name']}': {missing_conds} not found in "
                            f"design matrix. This usually means the trial_type was absent from "
                            f"the events file. Available columns: {list(dm.columns)}"
                        )
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
            parts.append(f"stat-{stat}_statmap")
        fname = "_".join(parts)
        return f"{prefix}{fname}{suffix}.{ext}"

    def process_and_fit_valid_run(self):
        from nilearn.glm import compute_contrast
        from nilearn.glm import first_level as level1
        from nilearn.plotting import plot_contrast_matrix, plot_design_matrix

        all_effect_maps = []
        all_variance_maps = []
        all_t_maps = []
        pipeline_sidecar = build_run_level_sidecar(
            participant_label=self.participant_label,
            task_label=self.task_label,
            space_label=self.space_label,
            dense=self.dense,
            model_spec_name=self.specs.get("Name", None),
            hrf_model=self.hrf_model,
            high_pass=self.high_pass,
            drift_model=self.drift_model,
            drop_duration=self.drop_duration,
            smoothing_fwhm=self.fwhm
        )
        for entry in self._iter_valid_runs():
            ses = entry["session"]
            task = entry["task"]
            run = entry["run"]

            ses_str = f"| ses-{ses} " if ses else ""
            run_str = f"| run-{run}" if run else ""
            task_str = f"| task-{task} "

            sub_run_imgs = self._get_func_img(run=run)
            cifti_in = sub_run_imgs[0].path

            logger.info(f"{'='*60}")
            logger.info(f"START sub-{self.participant_label} {ses_str}{task_str}{run_str}")
            logger.info(f"{'='*60}")

            if self.fwhm:
                l_surf, r_surf = get_cifti_surf(self.derivatives_dir, self.participant_label, session=ses, ciftify_dir=self.ciftify_dir)
                input_img = wb_smooth(cifti_in, l_surf, r_surf, fwhm=self.fwhm)
                logger.info(f"Smoothing input data by {self.fwhm} mm FWHM for fitting model -> {input_img}")
            else:
                input_img = cifti_in
                logger.info(f"The input data for model fitting -> {input_img}")

            logger.info(
                f"Generating design matrix for: {self.participant_label} {ses_str}{task_str}{run_str}"
            )
            dm = self.get_design_matrix(run, self.specs)
            logger.info(f"Columns of the convolved design matrix: {dm.columns}")
            logger.info(f"{'='*40}")
            logger.info(f"The functional image for GLM fit : {input_img}")
            new_cifti_img, _, _ = self.drop_non_steady_scans(
                sub_run_imgs, input_img
            )
                    
            is_cifti = isinstance(new_cifti_img, nb.Cifti2Image)
            if is_cifti:
                # Set up output directory
                if self.outputdir is not None:
                    self.outdir = Path(self.outputdir)
                else:
                    self.outdir = Path(self.derivatives_dir).parent / "glm" / "0.0.1"

                glm_dir = self.outdir / f"sub-{self.participant_label}"
                glm_dir.mkdir(exist_ok=True, parents=True)

                logger.info(
                    f"Fitting Model for subject: {self.participant_label} {ses_str}{task_str}{run_str}"
                )
                logger.info(f"{'='*40}")
                labels, estimates = level1.run_glm(
                    new_cifti_img.get_fdata(dtype="f4"), dm.values
                )

                # model_attr = {
                #     "r_square": self.dscalar_from_cifti(
                #         new_cifti_img,
                #         self._get_voxelwise_stat(labels, estimates, "r_square"),
                #         "r_square",
                #     ),
                #     "log_likelihood": self.dscalar_from_cifti(
                #         new_cifti_img,
                #         self._get_voxelwise_stat(labels, estimates, "logL"),
                #         "log_likelihood",
                #     ),
                #     "mean_square_error": self.dscalar_from_cifti(
                #         new_cifti_img,
                #         self._get_voxelwise_stat(labels, estimates, "MSE"),
                #         "mean_square_error",
                #     ),
                # }

                # Extract residuals (timepoints x grayordinates)
                residuals = self._get_voxelwise_stat(labels, estimates, "residuals")
                residual_img = nb.Cifti2Image(
                    residuals,
                    header=new_cifti_img.header,
                    nifti_header=new_cifti_img.nifti_header,
                )
                fname_residuals = os.path.join(
                    glm_dir,
                    self._format_filename(
                        participant_label=self.participant_label,
                        ses=ses,
                        task_label=task,
                        run=run,
                        suffix="_residuals",
                        ext="dtseries.nii",
                    ),
                )
                logger.info(f"Saving residuals: {fname_residuals}")
                residual_img.to_filename(fname_residuals)
            
            # save design matrix
            fname_dm = os.path.join(
                glm_dir,
                self._format_filename(
                    participant_label=self.participant_label,
                    ses=ses,
                    task_label=task,
                    run=run,
                    suffix="_design",
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
                    suffix="_design",
                    ext="svg",
                ),
            )
            logger.info(f"Saving the {fname_dm}")
            dm.to_csv(fname_dm, index=False)
            logger.info(f"Saving the {fname_dm_fig}")
            plot_design_matrix(dm, output_file=fname_dm_fig)

            # Accumulate run info for subject-level sidecar
            t_r = sub_run_imgs[0].get_metadata()["RepetitionTime"]
            update_run_level_sidecar(pipeline_sidecar, run, dm.columns.tolist(), t_r)

            # for attr, img in model_attr.items():
            #     fname = os.path.join(
            #         glm_dir,
            #         self._format_filename(
            #             participant_label=self.participant_label,
            #             ses=ses,
            #             task_label=task,
            #             run=run,
            #             stat=attr,
            #             ext="dscalar.nii",
            #         ),
            #     )
            #     logger.info(f"Saving Model outputs: {fname}")
            #     img.to_filename(fname)

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
                        suffix="_design",
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
                    # ("z_score", zscore_maps),
                    # ("p_value", pvalue_maps),
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
            all_t_maps.extend(stat_maps)

        finalize_run_level_sidecar(
            pipeline_sidecar, contrasts, all_effect_maps, all_variance_maps, all_t_maps
        )
        fname_sidecar = os.path.join(
            glm_dir,
            self._format_filename(
                participant_label=self.participant_label,
                ses=ses,
                task_label=task,
                suffix="_glm",
                ext="json",
            ),
        )
        write_sidecar(fname_sidecar, pipeline_sidecar)
        # Remove smoothed file and its json sidecar from fmriprep dir
        if self.fwhm:
            smoothed_path = Path(input_img)
            smoothed_json = smoothed_path.with_name(smoothed_path.name.replace("_bold.dtseries.nii", "_bold.json"))
            for tmp_file in [smoothed_path, smoothed_json]:
                if tmp_file.exists():
                    tmp_file.unlink()
                    logger.info(f"Deleted temporary smoothed file from fmriprep: {tmp_file}")
        return all_effect_maps, all_variance_maps, all_t_maps

    def compute_fix_effect(self, effect_maps, variance_maps):
        """
        Compute fixed-effects across multiple runs.

        Parameters
        ----------
        effect_maps : list of str
            List of file paths to effect size images (e.g., contrast maps).
        variance_maps : list of str
            List of file paths to corresponding variance images.
        Return:
            List of fixed-effect files
        Notes
        -----
        - At least two valid runs are required to compute the fixed-effects.
        """
        from collections import defaultdict

        from nilearn.glm.contrasts import _compute_fixed_effects_params

        if self.outputdir is not None:
            self.outdir = Path(self.outputdir)
        else:
            self.outdir = Path(self.derivatives_dir).parent / "glm" / "0.0.1"

        glm_dir = self.outdir / f"sub-{self.participant_label}"
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
                # "fixed_effect_variance": self.dscalar_from_cifti(
                #     img, ffx_var, "fixed_effect_variance"
                # ),
                "fixed_effect_stat": self.dscalar_from_cifti(
                    img, ffx_t, "fixed_effect_stat"
                ),
                # "fixed_effect_z_score": self.dscalar_from_cifti(
                #     img, ffx_z_score, "fixed_effect_z_score"
                # ),
            }

            # Save maps
            task_label = (
                self.task_label[0]
                if isinstance(self.task_label, list)
                else self.task_label
            )
            ffx_sidecar = build_fixed_effects_sidecar(
                participant_label=self.participant_label,
                session=session,
                task_label=task_label,
                contrast=contrast,
                n_runs=n_runs,
                contrast_imgs=contrast_imgs,
                variance_imgs=variance_imgs,
            )
            for map_type, cifti_img in maps.items():
                stat_label = (
                    "fixed_effect_t" if map_type == "fixed_effect_stat" else map_type
                )
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
                ffx_sidecar["outputs"][map_type] = fname
                logger.info(f"Plotting the computed fix-effect contrast: {map_type}")
                outname = fname.replace("dscalar.nii", "png")
                if map_type == "fixed_effect_stat" and isinstance(maps[map_type], nb.Cifti2Image):
                    plot_dscalar(maps[map_type], colorbar=False, output_file=outname)

            fname_sidecar = os.path.join(
                glm_dir,
                self._format_filename(
                    participant_label=self.participant_label,
                    ses=session,
                    task_label=task_label,
                    contrast=contrast,
                    suffix="_fixedeffects",
                    ext="json",
                ),
            )
            write_sidecar(fname_sidecar, ffx_sidecar)
