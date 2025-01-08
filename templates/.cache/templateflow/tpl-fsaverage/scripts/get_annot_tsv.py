# emacs: -*- mode: python; py-indent-offset: 4; indent-tabs-mode: nil -*-
# vi: set ft=python sts=4 ts=4 sw=4 et:
#
# Copyright 2024 The NiPreps Developers <nipreps@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# We support and encourage derived works from this project, please read
# about our expectations at
#
#     https://www.nipreps.org/community/licensing/
#
from pathlib import Path
import click
import numpy as np
import pandas as pd
import nibabel as nb


@click.command()
@click.argument("input_annot", type=click.Path(exists=True))
@click.argument("output_tsv", type=click.Path())
def run(input_annot, output_tsv):
    vert_lab, reg_ctable, reg_names = nb.freesurfer.read_annot(input_annot)

    df = pd.DataFrame(
        reg_ctable.byteswap().newbyteorder(),
        columns={
            "red": np.uint8,
            "green": np.uint8,
            "blue": np.uint8,
            "transparency": np.uint8,
            "index": np.uint32,
        }
    )
    df["name"] = [n.decode() for n in reg_names]
    df["alpha"] = 255 - df.transparency
    df["color"] = df.loc[:, ("red", "green", "blue", "alpha")].apply(
        lambda r: "#{:02x}{:02x}{:02x}{:02x}".format(*r),
        axis=1
    )
    df[["index", "name", "color"]].to_csv(output_tsv, sep="\t", index=None)

if __name__ == '__main__':
    run()

