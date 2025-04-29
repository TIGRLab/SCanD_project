import json
import logging
import os
import re
from functools import partial
from pathlib import Path
from warnings import warn

import nibabel as nib
import numpy as np
import pandas as pd

from .bids_util import LoadBidsModel
from .design_matrix import FirstLevelDesignMatrix
from .run_match import BoldEventsMatch

# Configure module logger
logger = logging.getLogger("bin.model_fit")


class FirstLevelModelFit(BoldEventsMatch):
    """
    A class to handle BIDS directory inputs for GLM analysis.

    This class stores essential information about a BIDS dataset and its
    derivatives, including the task, participant, session, space, and density
    parameters, and a BIDS Stat Model dictionary which are used to fit a GLM model on CIFTI files from fmriprep derivative.

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
    ):
        super().__init__(
            bids_dir,
            derivatives_dir,
            participant_label,
            task_label,
            session,
            space_label,
            dense,
        )
        self.specs = LoadBidsModel(model_spec)._ensure_model()

    def dscalar_from_cifti(self, img, data, name):
        import nibabel as nb
        import numpy as np

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
        """Generator that yields (session, run) tuples."""
        for session, run in self.match_runs:
            yield session, run

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

    def process_and_fit_valid_run(self):
        from nilearn.glm import compute_contrast
        from nilearn.glm import first_level as level1
        from nilearn.plotting import plot_contrast_matrix, plot_design_matrix

        for ses, run in self._iter_valid_runs():
            ses = ses.split("-")[1]  # Extract session (e.g., '01')
            run = run.split("-")[1]  # Extract run (e.g., '1')
            logger.info(
                f"Generating design matrix for: {self.participant_label} | ses-{ses} | run-{run}"
            )

            dm_instance = FirstLevelDesignMatrix(
                self.bids_dir,
                self.derivatives_dir,
                self.participant_label,
                self.task_label,
                self.session,
                self.space_label,
                self.dense,
            )
            dm = dm_instance.get_design_matrix(run, self.specs)
            logger.info(f"Columns of the convolved design matrix: {dm.columns}")
            logger.info(f"{'='*40}")
            sub_run_imgs, _, _ = dm_instance.get_data_from_bids(run)
            new_cifti_img, _, _ = dm_instance.drop_non_steady_scans(sub_run_imgs)
            is_cifti = isinstance(new_cifti_img, nib.Cifti2Image)
            if is_cifti:
                # Set up output directory
                outdir = Path(self.derivatives_dir).parent
                glm_dir = outdir / "glm" / f"sub-{self.participant_label}"
                glm_dir.mkdir(exist_ok=True, parents=True)
                fname_fmt = os.path.join(
                    glm_dir,
                    "sub-{}_ses-{}_task-{}_run-{}_contrast-{}_stat-{}_statmap.dscalar.nii",
                ).format
                modname_fmt = os.path.join(
                    glm_dir, "sub-{}_ses-{}_task-{}_run-{}_stat-{}_statmap.dscalar.nii"
                ).format

                logger.info(
                    f"Fitting Model for subject: {self.participant_label} | ses-{ses} | run-{run}"
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
                f"sub-{self.participant_label}_ses-{ses}_task-{self.task_label}_run-{run}_design.tsv",
            )
            fname_dm_fig = os.path.join(
                glm_dir,
                f"sub-{self.participant_label}_ses-{ses}_task-{self.task_label}_run-{run}_design.svg",
            )
            logger.info(f"Saving the design matrix to {glm_dir}")
            dm.to_csv(fname_dm, index=False)
            plot_design_matrix(dm, output_file=fname_dm_fig)

            # Save model level images
            model_metadata = []

            for attr, img in model_attr.items():
                model_metadata.append({"stat": attr})
                fname = modname_fmt(
                    self.participant_label, ses, self.task_label, run, attr
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
                    f"{self.participant_label}_ses-{ses}_task-{self.task_label}_run-{run}_contrast-{name}_stat-{contrast_test}.svg",
                )
                plot_contrast_matrix(weights, dm, output_file=fname_contrast)
                logger.info(f"\n{'='*40}")
                logger.info(
                    f"Computing contrast for: {self.participant_label} | ses-{ses} | run-{run}"
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
                    if map_type == "stat":
                        fname = fname_fmt(
                            self.participant_label,
                            ses,
                            self.task_label,
                            run,
                            name,
                            contrast_test,
                        )
                    else:
                        fname = fname_fmt(
                            self.participant_label,
                            ses,
                            self.task_label,
                            run,
                            name,
                            map_type,
                        )
                    logger.info(f"Saving Regressor output: {fname}")
                    map_list.append(fname)
                    maps[map_type].to_filename(fname)
        return effect_maps
