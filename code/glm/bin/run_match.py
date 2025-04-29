#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:
"""
Utilities to handle BIDS inputs
"""


import logging
import re
from warnings import warn

from .bids_util import BIDSSelect

# Configure logging
logger = logging.getLogger("bin.run_match")


class BoldEventsMatch(BIDSSelect):
    """
    Ensure fMRI BOLD NIfTI files and corresponding task event TSV files exist
    for a given participant, session, and task within a BIDS dataset at run-level.
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
    ):
        """
        Initializes the validator.

        Args:
            bids_dir (str): Path to the BIDS dataset.
            task_label (str): Task name to validate.
            participant_label (str, optional): Subject ID (e.g., "CMHWM01"). Defaults to None.
            session (str, optional): Session label (e.g., "01"). Defaults to None.
        """
        super().__init__(
            bids_dir,
            derivatives_dir,
            participant_label,
            task_label,
            session,
            space_label,
            dense,
        )
        self.match_runs = self._find_matching_runs()

    def __repr__(self):
        # Detailed string for debugging or logging
        params = "\n".join(f"  {key}: {value}" for key, value in self.__dict__.items())
        return f"Input Parameters(\n{params}\n)"

    def _find_matching_runs(self, verbose=True):
        match_runs = []
        missing_img_runs = set()
        missing_events_runs = set()

        session = f"ses-{self.session}"
        sub_imgs = self._get_func_img()
        sub_events = self._get_events_files()

        if not sub_imgs:
            raise ValueError(
                f"No functional images found for subject {self.participant_label} {session} "
            )
        if not sub_events:
            raise ValueError(
                f"No task events found for subject {self.participant_label} {session}"
            )

        # Extract available run numbers
        run_pattern = re.compile(r"run-(\d+)")
        img_runs = set()

        for img in sub_imgs:
            match = run_pattern.search(img.filename)
            if match:
                img_runs.add(int(match.group(1)))

        events_runs = set()
        for events in sub_events:
            match = run_pattern.search(events.filename)
            if match:
                events_runs.add(int(match.group(1)))

        # Find runs that are both in images and events
        matching_runs = img_runs.intersection(events_runs)

        if matching_runs:
            match_runs = [(session, f"run-{run}") for run in sorted(matching_runs)]
            # logger.info(
            #     f"Found match runs: {[run for run in match_runs]} for subject: {self.participant_label}"
            # )
        missing_img_runs = events_runs - img_runs
        missing_events_runs = img_runs - events_runs

        if missing_img_runs and verbose:
            logger.warning(
                f"{self.participant_label} has missing functional BOLD file for the following runs in {session}: run-{', '.join(map(str, missing_img_runs))}."
            )

        if missing_events_runs and verbose:
            logger.warning(
                f"{self.participant_label} has missing task events files for the following runs in {session}: run-{', '.join(map(str, missing_events_runs))}."
            )

        return match_runs
