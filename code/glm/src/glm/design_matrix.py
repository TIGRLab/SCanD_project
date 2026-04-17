#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging
import math
import warnings
from functools import partial

import nibabel as nib
import numpy as np
import pandas as pd
from nilearn.glm.first_level import make_first_level_design_matrix

from .bids_util import BIDSSelect, LoadBidsModel
from .run_match import BoldEventsMatch

logger = logging.getLogger("bin.design_matrix")


class FirstLevelDesignMatrix(BIDSSelect, LoadBidsModel):
    """
    Generate a design matrix using the matched-run task events and fMRI data per session for each participant.
    """

    hrf_model = "spm + derivative + dispersion"
    high_pass = 0.01
    drift_model = "cosine"
    mask_img = False
    minimize_memory = False

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
        drop_duration,
    ):
        BIDSSelect.__init__(
            self,
            bids_dir,
            derivatives_dir,
            participant_label,
            task_label,
            session,
            space_label,
            dense,
        )
        LoadBidsModel.__init__(self, model_spec)
        self.drop_duration = drop_duration

    def get_data_from_bids(self, run):
        """
        Collect the BIDS-formatted task events, smoothed CIFTI dtseries files, and associated confound
        regressor TSVs for each matched run within a specific subject and session.

        Returns:
            sub_run_smoothed_imgs (list): List of BIDSFile object corresponding to run-level smoothed CIFTI dtseries.
            sub_run_imgs (list): List of BIDSFile object corresponding to run-level CIFTI dtseries.
            sub_run_events (list): List of BIDSFile object corresponding to run-level task event TSV files.
            sub_run_confounds (list): List of BIDSFile object corresponding to run-level confound regressor TSV files.
        """
        sub_run_smoothed_imgs = self._get_smoothed_func_img(run)
        sub_run_imgs = self._get_func_img(run)
        sub_run_events = self._get_events_files(run)
        sub_run_confounds = self._get_confounds_files(run)

        if not sub_run_imgs or not sub_run_events or not sub_run_confounds:
            raise ValueError(
                f"Expected 3 files for sub-{self.participant_label}, only getting {len(sub_run_imgs) + len(sub_run_events) + len(sub_run_confounds)}"
            )
        return sub_run_imgs, sub_run_smoothed_imgs, sub_run_events, sub_run_confounds

    def _load_run_level_events(self, sub_run_events, model_spec):
        try:
            events_df = pd.read_csv(sub_run_events[0].path, sep=None, engine="python")
        except pd.errors.ParserError as e:
            raise ValueError(f"Could not parse {sub_run_events[0].path}: {e}")

        if "modulation" in events_df.columns:
            events_df = events_df[["onset", "duration", "trial_type", "modulation"]]
        else:
            events_df = events_df[["onset", "duration", "trial_type"]]

        # Account for 4 seconds drops so first trial start time is shifted by 4 seconds
        events_df["onset"] = events_df["onset"] - self.drop_duration
        logger.info(
            f"Found: {', '.join(events_df['trial_type'].unique())} from BIDS task events "
        )

        # Get the Model X inputs from root/Run node
        for node in model_spec["Nodes"]:
            if node["Level"] == "Run":
                x_inputs = node["Model"]["X"]
                if not x_inputs:
                    raise ValueError(
                        f"Node '{node['Name']}' at Run level has no regressors (X). "
                        "Cannot format events_df for GLM."
                    )

                # Trial types in events_df that are not in model spec
                trial_types_in_df = set(events_df["trial_type"].unique())
                missing = trial_types_in_df - set(x_inputs)
                if missing:
                    logger.warning(
                        f"Node '{node['Name']}': {', '.join(missing)} trial_type not provided in BIDS Stat Model"
                    )
                mask = events_df["trial_type"].isin(x_inputs)
                events_df = events_df.loc[mask]
                if events_df.empty:
                    raise ValueError(
                        f"No condition of interest was specifed\n"
                        f"Provide one of the trial_type: {', '.join(trial_types_in_df)}"
                    )
            else:
                raise ValueError(f"Run node is not identified in model specification")

        return events_df

    # I have to add a function to calculate the TR drop and actually drop them and edit the onset in the events dataframe

    def drop_non_steady_scans(self, sub_run_img, sub_run_smoothed_img):
        "Calculate the number of non steady scans using the drop duration seconds and RepetitionTime"
        cifti_img = nib.load(sub_run_smoothed_img)
        is_cifti = isinstance(cifti_img, nib.Cifti2Image)
        if isinstance(cifti_img, nib.dataobj_images.DataobjImage):
            # Ugly hack to ensure that retrieved data isn't cast to float64 unless
            # necessary to prevent an overflow
            # For NIfTI-1 files, slope and inter are 32-bit floats, so this is
            # "safe". For NIfTI-2 (including CIFTI-2), these fields are 64-bit,
            # so include a check to make sure casting doesn't lose too much.
            slope32 = np.float32(cifti_img.dataobj._slope)
            inter32 = np.float32(cifti_img.dataobj._inter)
            close = partial(np.isclose, atol=1e-7, rtol=0)
            if close(slope32, cifti_img.dataobj._slope) and close(
                inter32, cifti_img.dataobj._inter
            ):
                cifti_img.dataobj._slope = slope32
                cifti_img.dataobj._inter = inter32
        if is_cifti:
            cifti_data = cifti_img.get_fdata(dtype="f4")
            t_r = sub_run_img[0].get_metadata()["RepetitionTime"]
            non_steady_scans = math.ceil(self.drop_duration / t_r)

            # drop non steady scans from the data
            new_cifti_data = cifti_data[non_steady_scans:, :]
            n_scans = new_cifti_data.shape[0]

            # Create new CIFTI image with updated header
            origin_cifti_header = cifti_img.header
            # Create new axes 0 to match new mat size and store orig axes 1
            ax_0 = nib.cifti2.SeriesAxis(
                start=0, step=t_r, size=new_cifti_data.shape[0]
            )
            ax_1 = origin_cifti_header.get_axis(1)
            # Create new header and cifti object
            new_header = nib.cifti2.Cifti2Header.from_axes((ax_0, ax_1))
            new_cifti_img = nib.cifti2.Cifti2Image(new_cifti_data, header=new_header)
            # Calculate the timing of acquisition of the scans in seconds
            frame_times = np.arange(n_scans) * t_r
        else:
            raise ValueError(f"Expected CIFTI file")

        return new_cifti_img, frame_times, non_steady_scans

    @staticmethod
    def extract_confounds_from_model_spec(model_spec, sub_run_confounds_path):
        """
        Extract confound variables from model spec
        Return None if no confound variable found in model (to trigger default usage)
        """

        try:
            run_node = None
            for node in model_spec.get("Nodes", []):
                if node.get("Level").lower() == "run":
                    run_node = node
                    break
            if not run_node:
                return None
            x_vars = run_node.get("Model", {}).get("X", [])

            # Identify regressor
            # Load confound columns available in confounds TSV file
            confounds_df = pd.read_csv(sub_run_confounds_path, delimiter="\t")
            available_confounds = set(confounds_df.columns)

            # Identify which x_vars are confounds by intersection
            confound_vars = [var for var in x_vars if var in available_confounds]

            if len(confound_vars) == 0:
                return None

            return confound_vars

        except Exception as e:
            logger.warning(f"Could not extract confounds from model spec: {e}")
            return None

    def get_design_matrix(self, run, model_spec):
        """
        Make design matrix by run-specific" 
        """
        sub_run_imgs, sub_run_smoothed_imgs, sub_run_events, sub_run_confounds = (
            self.get_data_from_bids(run)
        )
        sub_run_events_df = self._load_run_level_events(sub_run_events, model_spec)
        _, frame_times, non_steady_scans = self.drop_non_steady_scans(
            sub_run_img=sub_run_imgs, sub_run_smoothed_img=sub_run_smoothed_imgs
        )

        # Confound regressors
        confounds_df = pd.read_csv(sub_run_confounds[0].path, delimiter="\t")

        # Try to get confounds from model specs first
        confound_vars = self.extract_confounds_from_model_spec(
            model_spec, sub_run_confounds[0].path
        )

        # Default exact column names. Need to update so allow users to include more variables
        if confound_vars is None:
            confound_vars = [
                "white_matter",
                "csf",
                "framewise_displacement",
                "trans_x",
                "trans_y",
                "trans_z",
                "rot_x",
                "rot_y",
                "rot_z",
            ]
            logger.info(f"Using default confounds: {confound_vars}")
        else:
            logger.info(f"Using confounds from model specification: {confound_vars}")
        confounds_df = confounds_df[confound_vars]
        confounds_df = confounds_df[non_steady_scans:]

        # Demean the regressors but we have the constant in the deisgn-matrix already so no need
        # for col in confounds_df.columns:
        #     confounds_df.loc[:, col] = confounds_df[col].sub(confounds_df[col].mean())

        if sub_run_events_df["onset"].max() > frame_times[-1]:
            raise ValueError(
                f"Events extend beyond scan duration ({frame_times[-1]:.1f}s). "
                f"Last event onset: {sub_run_events_df['onset'].max():.1f}s. "
                f"Scan may be truncated or the wrong run was matched to the events file."
            )

        dm = make_first_level_design_matrix(
            frame_times,
            sub_run_events_df,
            drift_model=self.drift_model,
            high_pass=self.high_pass,
            add_regs=confounds_df,
            add_reg_names=list(confounds_df.columns),
            hrf_model=self.hrf_model,
        )
        return dm
