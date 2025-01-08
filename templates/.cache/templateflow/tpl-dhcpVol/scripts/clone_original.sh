#!/bin/bash
# Clone the G-Node GIN repository containing the original template
# All files in the repo seem to be indexed with git,
# so we don't need to use datalad get.
datalad clone \
    git@gin.g-node.org:/BioMedIA/dhcp-volumetric-atlas-groupwise.git \
    ../../dhcp-volumetric-atlas-groupwise
