#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging
import math
from functools import partial

import nibabel as nib
import numpy as np
import pandas as pd
from nilearn.glm.first_level import make_first_level_design_matrix

from .bids_util import BIDSSelect, LoadBidsModel
from .run_match import BoldEventsMatch

logger = logging.getLogger("bin.design_matrix")


class FirstLevelDesignMatrix(BIDSSelect):
    """
    Generate a design matrix using the matched-run task events and fMRI data per session for each participant.
    """

    hrf_model = "spm + derivative + dispersion"
    high_pass = 0.01
    drift_model = "cosine"
    mask_img = False
    minimize_memory = False
    drop_duration = 4  # in seconds use to adjust for the first few the non-steady scans

    def __init__(
        self,
        bids_dir,
        derivatives_dir,
        participant_label,
        task_label,
        session,
        space_label,
        dense,
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

    def get_data_from_bids(self, run):
        """
        Collect the BIDS-formatted task events, CIFTI dtseries files, and associated confound
        regressor TSVs for each matched run within a specific subject and session.

        Returns:
            sub_run_imgs (list): List of BIDSFile objects corresponding to CIFTI dtseries images.
            sub_run_events (list): List of BIDSFile objects for task event TSV files.
            sub_run_confounds (list): List of BIDSFile objects for confound regressor TSV files.
        """
        sub_run_events = self.layout.get(
            extension="tsv",
            task=self.task_label,
            subject=self.participant_label,
            session=self.session,
            run=run,
            suffix="events",
            scope="raw",
        )

        sub_run_imgs = self.layout.get(
            extension="dtseries.nii",
            suffix="bold",
            task=self.task_label,
            subject=self.participant_label,
            session=self.session,
            run=run,
            space="fsLR",
            den="91k",
        )

        sub_run_confounds = self.layout.get(
            extension="tsv",
            task=self.task_label,
            subject=self.participant_label,
            session=self.session,
            desc="confounds",
            scope="derivatives",
            run=run,
            suffix="timeseries",
        )
        if not sub_run_imgs or not sub_run_events or not sub_run_confounds:
            raise ValueError(
                f"Expected 3 files for sub-{self.participant_label}, only getting {len(sub_run_imgs) + len(sub_run_events) + len(sub_run_confounds)}"
            )
        return sub_run_imgs, sub_run_events, sub_run_confounds

    def _load_run_level_events(self, sub_run_events, model_spec):
        events_df = pd.read_csv(sub_run_events[0].path, delimiter="\t")

        if model_spec["Input"]["task"][0] == "nbk":
            # Extract hit, miss, and false alarm from n-back
            mask_hit = (events_df["correct_response"] == 1) & (
                events_df["participant_response"] == 1
            )
            mask_miss = (events_df["correct_response"] == 1) & (
                events_df["participant_response"] == 0
            )
            mask_false = (events_df["correct_response"] == 0) & (
                events_df["participant_response"] == 1
            )

            events_df.loc[mask_hit, "trial_type"] = (
                events_df["trial_type"].astype(str) + "_hit"
            )
            events_df.loc[mask_false, "trial_type"] = (
                events_df["trial_type"].astype(str) + "_false"
            )
            events_df["onset"] = events_df["onset"] + 8
        events_df = events_df[["onset", "duration", "trial_type"]]

        # Account for 4 seconds drops so first trial start time is shifted by 4 seconds
        events_df["onset"] = events_df["onset"] - self.drop_duration
        logger.info(f"Trial types: {events_df['trial_type'].unique()}")

        # Get the Model X inputs from root/Run node
        for node in model_spec["Nodes"]:
            if node["Level"] == "Run":
                x_inputs = node["Model"]["X"]
                mask = events_df["trial_type"].str.contains("|".join(x_inputs))
                events_df = events_df.loc[mask]
            else:
                logger.warning(f"Run node is not identified in model specification")

        return events_df

    # I have to add a function to calculate the TR drop and actually drop them and edit the onset in the events dataframe

    def drop_non_steady_scans(self, sub_run_imgs):
        "Calculate the number of non steady scans using the drop duration of 4 seconds and RepetitionTime"
        cifti_img = nib.load(sub_run_imgs[0].path)
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
            t_r = sub_run_imgs[0].get_metadata()["RepetitionTime"]
            non_steady_scans = math.ceil(self.drop_duration / t_r)
            # drop non steady scans from the data
            new_cifti_data = cifti_data[non_steady_scans:, :]
            new_cifti_img = nib.Cifti2Image(new_cifti_data, header=cifti_img.header)
            n_scans = new_cifti_data.shape[0]
            # Calculate the timing of acquisition of the scans in seconds
            frame_times = np.arange(n_scans) * t_r
        else:
            raise ValueError(f"Expected CIFTI file")

        return new_cifti_img, frame_times, non_steady_scans

    def get_design_matrix(self, run, model_spec):

        sub_run_imgs, sub_run_events, sub_run_confounds = self.get_data_from_bids(run)
        sub_run_events_df = self._load_run_level_events(sub_run_events, model_spec)
        _, frame_times, non_steady_scans = self.drop_non_steady_scans(sub_run_imgs)

        # Confound regressors
        confounds_df = pd.read_csv(sub_run_confounds[0].path, delimiter="\t")
        confound_vars = [
            col
            for col in confounds_df.columns
            if col.startswith(("white_matter", "csf", "trans", "rot"))
        ]
        confounds_df = confounds_df[confound_vars]
        # confounds_df = confounds_df[
        #     [
        #         "csf",
        #         "white_matter",
        #         "trans_x",
        #         "trans_y",
        #         "trans_z",
        #         "rot_x",
        #         "rot_y",
        #         "rot_z",
        #         "framewise_displacement"
        #     ]
        # ]

        confounds_df = confounds_df[non_steady_scans:]

        # Demean the regressors but we have the constant in the deisgn-matrix already so no need
        # for col in confounds_df.columns:
        #     confounds_df.loc[:, col] = confounds_df[col].sub(confounds_df[col].mean())

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
