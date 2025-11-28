#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:
"""
Utilities to handle BIDS inputs
"""

import json
import logging
import os
from pathlib import Path
from warnings import warn

from bids import BIDSLayout, BIDSLayoutIndexer
from bids.layout import BIDSFile

# Setup logging configuration
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class LoadBidsModel:

    def __init__(self, model_spec):
        self.model_spec = model_spec
        self.specs = self._ensure_model()

    def _ensure_model(self):
        model = getattr(self.model_spec, "filename", self.model_spec)

        if isinstance(model, str):
            if os.path.exists(model):
                with open(model) as fobj:
                    model = json.load(fobj)
                    self._validate_input_field(model)
            else:
                # raise error if it's a path but does not exist
                if model.endswith(".json"):
                    raise FileNotFoundError(
                        f"Model Specifications file not found: {model}"
                    )
                try:
                    model = json.loads(model)
                    self._validate_input_field(model)
                except json.JSONDecodeError:
                    raise ValueError(
                        "Provided model_spec is neither a valid path nor valid JSON string."
                    )

        return model

    def _validate_input_field(self, model):
        required_fields = ["task", "session", "space", "dense"]
        input_field = model.get("Input", {})
        missing = [field for field in required_fields if field not in input_field]
        if missing:
            raise ValueError(f"Missing required Input fields: {missing}")


class BIDSSelect:

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
        self.bids_dir = bids_dir
        self.derivatives_dir = derivatives_dir
        self.participant_label = participant_label
        self.task_label = task_label
        self.session = session
        self.space_label = space_label
        self.dense = dense
        # self.indexer = BIDSLayoutIndexer(ignore=[f'sub-(?!{self.participant_label}).*'])
        self.layout = BIDSLayout(
            self.bids_dir,
            derivatives=self.derivatives_dir,
            validate=False,
            ignore=[f"(?!sub-{participant_label}).*"],
        )

        if self.participant_label not in self.layout.get_subject():
            raise ValueError(
                f"No BIDS dataset found for subject: {self.participant_label}"
            )

    def _get_func_img(self, run=None):

        query = dict(
            subject=self.participant_label,
            session=self.session,
            task=self.task_label,
            space="fsLR",
            den="91k",
            extension="dtseries.nii",
            suffix="bold",
            desc=None,
        )
        if run is not None:  # only add run if specified
            query["run"] = run
        return self.layout.get(**query)

    def _get_smoothed_func_img(self, run=None):
        raw_file = self._get_func_img(run)[0].path
        smoothed_file = Path(raw_file).with_name(
            Path(raw_file).name.replace(
                "_bold.dtseries.nii", "_desc-Smoothed_bold.dtseries.nii"
            )
        )
        if not smoothed_file.exists():
            raise FileNotFoundError(f"Missing Smoothed dtseries")
        return smoothed_file
        # query = dict(
        #     subject=self.participant_label,
        #     session=self.session,
        #     task=self.task_label,
        #     space="fsLR",
        #     den="91k",
        #     extension="dtseries.nii",
        #     suffix="bold",
        #     desc="Smoothed",
        # )

        # if run is not None:  # only add run if specified
        #     query["run"] = run
        # return self.layout.get(**query)

    def _get_events_files(self, run=None):
        query = dict(
            subject=self.participant_label,
            session=self.session,
            task=self.task_label,
            suffix="events",
            scope="raw",
            extension="tsv",
        )

        if run is not None:  # only add run if specified
            query["run"] = run
        return self.layout.get(**query)

    def _get_confounds_files(self, run=None):
        query = dict(
            subject=self.participant_label,
            session=self.session,
            task=self.task_label,
            desc="confounds",
            scope="derivatives",
            suffix="timeseries",
            extension="tsv",
        )

        if run is not None:
            query["run"] = run
        return self.layout.get(**query)

    def __repr__(self):
        # Detailed string for debugging or logging
        params = "\n".join(f"  {key}: {value}" for key, value in self.__dict__.items())
        return f"Input Parameters: (\n{params}\n"
