#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Validate fMRI BOLD and task events at run-level for a BIDS dataset.
"""

import logging

from .bids_util import BIDSSelect

logger = logging.getLogger(__name__)


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
        self.match_runs = self._find_matching_runs()

    def __repr__(self):
        return (
            f"BoldEventsMatch("
            f"sub-{self.participant_label}, "
            f"ses-{self.session}, "
            f"task-{self.task_label}, "
            f"matched_runs={[r['run'] for r in self.match_runs]})"
        )

    @staticmethod
    def get_task_run_id(file):
        """Return a (task, run) tuple identifying a run, or (task,) for runless tasks."""
        task = file.entities.get("task")
        run = file.entities.get("run")
        return (task, int(run)) if run is not None else (task,)

    @staticmethod
    def _format_pair(pair):
        """Format a (task,) or (task, run) tuple into a readable string."""
        if len(pair) == 2:
            task, run = pair
            return f"task-{task} run-{run}"
        return f"task-{pair[0]}"

    def _find_matching_runs(self):
        """Return runs that have both a BOLD image and an events file."""
        session_str = f"ses-{self.session}" if self.session else "no session"

        sub_imgs = self._get_func_img()
        sub_events = self._get_events_files()

        if not sub_imgs:
            raise ValueError(
                f"No functional images found for sub-{self.participant_label} {session_str}"
            )
        if not sub_events:
            raise ValueError(
                f"No task events found for sub-{self.participant_label} {session_str}"
            )

        img_pairs = {self.get_task_run_id(f) for f in sub_imgs}
        event_pairs = {self.get_task_run_id(f) for f in sub_events}

        matching_pairs = img_pairs & event_pairs
        missing_imgs = event_pairs - img_pairs
        missing_events = img_pairs - event_pairs

        for pair in missing_imgs:
            logger.warning(
                f"sub-{self.participant_label} {session_str}: "
                f"events file found but no BOLD image for {self._format_pair(pair)}"
            )
        for pair in missing_events:
            logger.warning(
                f"sub-{self.participant_label} {session_str}: "
                f"BOLD image found but no events file for {self._format_pair(pair)}"
            )

        if not matching_pairs:
            raise ValueError(
                f"No runs with both BOLD and events found for "
                f"sub-{self.participant_label} {session_str}"
            )

        result = []
        for pair in sorted(matching_pairs):
            task, run = pair if len(pair) == 2 else (pair[0], None)
            result.append({"session": self.session, "task": task, "run": run})
        return result
