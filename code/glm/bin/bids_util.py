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
from warnings import warn

from bids import BIDSLayout, BIDSLayoutIndexer

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
                model = json.loads(model)
                self._validate_input_field(model)

        return model

    def _validate_input_field(self, model):
        required_fields = ["task", "session", "space", "dense"]
        input_field = model.get("Input", {})
        missing = [field for field in required_fields if field not in input_field]
        if missing:
            raise ValueError(f"Missing required Input fields: {missing}")
        else:
            print("All required Input fields are present")


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
            self.bids_dir, derivatives=self.derivatives_dir, validate=False
        )
        if self.participant_label not in self.layout.get_subject():
            raise ValueError(
                f"No BIDS dataset found for subject: {self.participant_label}"
            )

    def _get_func_img(self):
        sub_imgs = self.layout.get(
            extension="dtseries.nii",
            suffix="bold",
            task=self.task_label,
            subject=self.participant_label,
            session=self.session,
            space="fsLR",
            den="91k",
        )
        return sub_imgs

    def _get_events_files(self):
        sub_events_files = self.layout.get(
            extension="tsv",
            task=self.task_label,
            subject=self.participant_label,
            session=self.session,
            suffix="events",
            scope="raw",
        )
        return sub_events_files

    def __repr__(self):
        # Detailed string for debugging or logging
        params = "\n".join(f"  {key}: {value}" for key, value in self.__dict__.items())
        return f"Input Parameters: (\n{params}\n"
