#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:
"""
Validate fMRI BOLD and task events at run-level for a BIDS dataset.
"""

import logging
import re
from warnings import warn

from .bids_util import BIDSSelect

# Configure logging
# logger = logging.getLogger("bin.run_match")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

class BoldEventsMatch(BIDSSelect):
    """
    Ensures that for a given participant, session, and task, 
    only runs with both BOLD images and events files are returned.
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
        verbose=True
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
        self.verbose = verbose
        self.match_runs = self._find_matching_runs()

    def __repr__(self):
        # Detailed string for debugging or logging
        params = "\n".join(f"  {key}: {value}" for key, value in self.__dict__.items())
        return f"Input Parameters(\n{params}\n)"
    
    @staticmethod
    def get_task_run_id(file):
        """Return a tuple identifying a task/run combination.
        Runless tasks return a single-element tuple.
        """
        run = file.entities.get("run")
        task = file.entities.get("task")
        if run is None:
            return (task,)  # single-element tuple
        return (task, int(run))

    def _find_matching_runs(self, verbose=True):
        """Return a list of runs that have both BOLD images and events files."""

        session_label = f"{self.session}" if self.session else None
        sub_imgs = self._get_func_img()
        sub_events = self._get_events_files()

        if not sub_imgs:
            raise ValueError(
                f"No functional images found for {self.participant_label} {session_label}"
            )
        if not sub_events:
            raise ValueError(
                f"No task events found for {self.participant_label} {session_label}"
            )

        # Collect task/run tuples
        task_run_pairs_img = {self.get_task_run_id(img) for img in sub_imgs}
        task_run_pairs_events = {self.get_task_run_id(ev) for ev in sub_events}

        # Find matches and missing files
        matching_pairs = task_run_pairs_img.intersection(task_run_pairs_events)
        missing_imgs = task_run_pairs_events - task_run_pairs_img
        missing_events = task_run_pairs_img - task_run_pairs_events

        # Verbose warnings
        if verbose:
            session_str = f" | ses-{self.session}" if self.session else ""
            if missing_imgs:
                for pair in missing_imgs:
                    message = []
                    if len(pair) == 2:
                        task, run = pair
                        message.append(f"{task} | run-{run} ")
                    else:
                        task, = pair
                        message.append(task)
                
                    logger.warning(
                        f"{self.participant_label} missing BOLD files for: "
                        f"{', '.join(message)} {session_str}"
                    )
            if missing_events:
                for pair in missing_events:
                    message = []
                    if len(pair) == 2:
                        task, run = pair
                        message.append(f"{task} | run-{run} ")
                    else:
                        task, = pair
                        message.append(task)
                logger.warning(
                    f"{self.participant_label} missing events files for: "
                    f"{', '.join(message)} {session_str}"
                )

        # Prepare result list
        result = []
        for pair in sorted(matching_pairs):
            if len(pair) == 2:
                task, run = pair
            else:
                task, = pair
                run = None
            result.append({
                "session": self.session, 
                "task": task,
                "run": run
                })
        return result
