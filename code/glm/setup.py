#!/usr/bin/env python
# -*- coding: utf-8 -*-
# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:

from setuptools import find_packages, setup

setup(
    name="glm",
    version="0.0.1",
    author="Your Name",
    description="GLM postprocessing pipeline for fMRI surface data",
    packages=find_packages(include=["glm", "glm.*"]),
    include_package_data=True,
    install_requires=[
        "nilearn==0.11.1",
        "nipype==1.9.2",
        "matplotlib==3.8.4",
        "pybids==0.15.6",
    ],
    entry_points={
        "console_scripts": [
            "glm-run=glm.run:main",  # glm/run.py
        ],
    },
    python_requires=">=3.10.7",
)
