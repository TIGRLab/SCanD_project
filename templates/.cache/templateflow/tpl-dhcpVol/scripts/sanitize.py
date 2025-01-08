"""Convert the original dHCP volumetric atlas to TemplateFlow format."""

import json
import os
import shutil
from glob import glob
from pathlib import Path

import nibabel as nb
import numpy as np
import pandas as pd
from nilearn import image


def convert_templates(in_dir, out_dir):
    """Convert the original templates to TemplateFlow format.

    This includes a brain mask, T1w, T2w, and discrete segmentations,
    for each cohort.
    """
    mean_dir = os.path.join(in_dir, "mean")
    age_dirs = sorted(glob(os.path.join(mean_dir, "ga_*")))
    ages = [os.path.basename(age_dir) for age_dir in age_dirs]

    # Specify the mapping from the original file names to the new ones.
    template_dict = {
        "mask": "tpl-dhcpVol_cohort-{weeks}_desc-brain_mask",
        "structures": "tpl-dhcpVol_cohort-{weeks}_desc-structures_dseg",
        "template_t1": "tpl-dhcpVol_cohort-{weeks}_T1w",
        "template_t2": "tpl-dhcpVol_cohort-{weeks}_T2w",
        "tissues": "tpl-dhcpVol_cohort-{weeks}_desc-tissues_dseg",
    }

    for age in ages:
        weeks = age.split("_")[1]
        cohort_dir = os.path.join(out_dir, f"cohort-{weeks}")
        os.makedirs(cohort_dir, exist_ok=True)

        template_dir = os.path.join(mean_dir, age)

        # Copy the untouched files
        for k, v in template_dict.items():
            in_file = os.path.join(template_dir, f"{k}.nii.gz")
            out_file = os.path.join(cohort_dir, v.format(weeks=weeks) + ".nii.gz")
            shutil.copyfile(in_file, out_file)


def convert_segmentations(in_dir, out_dir):
    """Convert the original probabilistic atlases to TemplateFlow format."""
    mean_dir = os.path.join(in_dir, "mean")
    age_dirs = sorted(glob(os.path.join(mean_dir, "ga_*")))
    ages = [os.path.basename(age_dir) for age_dir in age_dirs]

    for age in ages:
        weeks = age.split("_")[1]
        cohort_dir = os.path.join(out_dir, f"cohort-{weeks}")
        os.makedirs(cohort_dir, exist_ok=True)

        struct_dir = os.path.join(in_dir, "structures", age)
        tissue_dir = os.path.join(in_dir, "tissues", age)

        # There are a series of tissue-specific posterior probability maps
        # that need to be concatenated into a single image.
        # Values in these maps go from 0 to 10000.
        tissue_psegs = sorted(glob(os.path.join(tissue_dir, "tissue_*.nii.gz")))
        tissue_pseg_img = image.concat_imgs(tissue_psegs)
        # Scale from [0, 10000] to [0, 1]
        tissue_pseg_data = tissue_pseg_img.get_fdata()
        tissue_pseg_data = tissue_pseg_data / np.max(tissue_pseg_data)
        tissue_pseg_img = nb.Nifti1Image(
            tissue_pseg_data,
            affine=tissue_pseg_img.affine,
            header=tissue_pseg_img.header,
        )
        out_tissue_pseg = os.path.join(
            cohort_dir,
            f"tpl-dhcpVol_cohort-{weeks}_desc-tissues_probseg.nii.gz",
        )
        tissue_pseg_img.to_filename(out_tissue_pseg)

        # There are a series of structure-specific posterior probability maps
        # that need to be concatenated into a single image.
        # Values in these maps go from 0 to 10000.
        struct_psegs = sorted(glob(os.path.join(struct_dir, "structure_*.nii.gz")))
        struct_pseg_img = image.concat_imgs(struct_psegs)
        # Scale from [0, 10000] to [0, 1]
        struct_pseg_data = struct_pseg_img.get_fdata()
        struct_pseg_data = struct_pseg_data / np.max(struct_pseg_data)
        struct_pseg_img = nb.Nifti1Image(
            struct_pseg_data,
            affine=struct_pseg_img.affine,
            header=struct_pseg_img.header,
        )
        out_struct_pseg = os.path.join(
            cohort_dir,
            f"tpl-dhcpVol_cohort-{weeks}_desc-structures_probseg.nii.gz",
        )
        struct_pseg_img.to_filename(out_struct_pseg)


def convert_atlas_metadata(in_dir, out_dir):
    """Convert the original atlases' metadata to TemplateFlow format."""
    probseg_desc = {
        "red": {
            "Description": (
                "The red component of the region's specified color, "
                "ranging from 0 to 255."
            ),
            "LongName": "Red Color",
        },
        "green": {
            "Description": (
                "The green component of the region's specified color, "
                "ranging from 0 to 255."
            ),
            "LongName": "Green Color",
        },
        "blue": {
            "Description": (
                "The blue component of the region's specified color, "
                "ranging from 0 to 255."
            ),
            "LongName": "Blue Color",
        },
        "opacity": {
            "Description": (
                "The opacity to be used when rendering the region, "
                "ranging from 0 to 1."
            ),
            "LongName": "Opacity",
        },
        "visibility": {
            "Description": "Label visibility",
            "Levels": {
                "0": "Do not show label",
                "1": "Show label",
            },
        },
    }
    with open(os.path.join(out_dir, "tpl-dhcpVol_probseg.json"), "w") as fo:
        json.dump(probseg_desc, fo, sort_keys=True, indent=4)

    with open(os.path.join(out_dir, "tpl-dhcpVol_dseg.json"), "w") as fo:
        json.dump(probseg_desc, fo, sort_keys=True, indent=4)

    # Convert the irtkSegmentTable-format files for the segmentations to TSVs
    tissues_df = pd.read_table(
        os.path.join(in_dir, "config", "tissues.txt"),
        skiprows=1,
        names=["index", "red", "green", "blue", "opacity", "thing", "name"],
    )
    tissues_df.to_csv(
        os.path.join(out_dir, "tpl-dhcpVol_desc-tissues_probseg.tsv"),
        sep="\t",
        index=False,
    )
    tissues_df.to_csv(
        os.path.join(out_dir, "tpl-dhcpVol_desc-tissues_dseg.tsv"),
        sep="\t",
        index=False,
    )

    structures_df = pd.read_table(
        os.path.join(in_dir, "config", "structures.txt"),
        skiprows=1,
        names=["index", "red", "green", "blue", "opacity", "thing", "name"],
    )
    structures_df.to_csv(
        os.path.join(out_dir, "tpl-dhcpVol_desc-structures_probseg.tsv"),
        sep="\t",
        index=False,
    )
    structures_df.to_csv(
        os.path.join(out_dir, "tpl-dhcpVol_desc-structures_dseg.tsv"),
        sep="\t",
        index=False,
    )


def write_template_description(out_dir):
    """Write the template_description.json file."""
    desc = {
        "Authors": [
            "Schuh A",
            "Makropoulos A",
            "Robinson EC",
            "Cordero-Grande L",
            "Hughes E",
            "Hutter J",
            "Price AN",
            "Murgasova M",
            "Teixeira RPA",
            "Tusor N",
            "Steinweg JK",
            "Victor S",
            "Rutherford MA",
            "Hajnal JV",
            "Edwards AD",
            "Rueckert D",
        ],
        "BIDSVersion": "1.8.0",
        "Curators": ["Salo T"],
        "Description": (
            "Unbiased morphological atlas of neonatal brain development "
            "constructed using neonatal brain images acquired and processed "
            "as part of the Developing Human Connectome Project (dHCP)."
        ),
        "Identifier": "dhcpVol",
        "License": "CC-BY 4.0",
        "Name": (
            "Unbiased and temporally consistent morphological atlas of "
            "neonatal brain development"
        ),
        "ReferencesAndLinks": [
            "https://doi.org/10.1101/251512",
            "https://doi.org/10.12751/g-node.d2b353",
        ],
        "Species": "Homo sapiens",
        "TemplateFlowVersion": "1.0.0",
        "cohort": {
            "36": {"age": [36], "units": "weeks"},
            "37": {"age": [37], "units": "weeks"},
            "38": {"age": [38], "units": "weeks"},
            "39": {"age": [39], "units": "weeks"},
            "40": {"age": [40], "units": "weeks"},
            "41": {"age": [41], "units": "weeks"},
            "42": {"age": [42], "units": "weeks"},
            "43": {"age": [43], "units": "weeks"},
            "44": {"age": [44], "units": "weeks"},
        },
    }
    with open(os.path.join(out_dir, "template_description.json"), "w") as fo:
        json.dump(desc, fo, sort_keys=True, indent=4)


def sanitize(input_fname):
    """Taken from sanitize.py in the MNIInfant TemplateFlow repo.

    https://github.com/templateflow/tpl-MNIInfant/blob/\
    e19e5a83e3130b7493bef0e8989435fd6b5ceeb6/scripts/sanitize.py
    """
    im = nb.as_closest_canonical(nb.squeeze_image(nb.load(str(input_fname))))
    hdr = im.header.copy()
    dtype = "int16"
    data = None
    if str(input_fname).endswith("_mask.nii.gz"):
        dtype = "uint8"
        data = im.get_fdata() > 0

    if str(input_fname).endswith("_probseg.nii.gz"):
        dtype = "float32"
        hdr["cal_max"] = 1.0
        hdr["cal_min"] = 0.0
        data = im.get_fdata()
        data[data < 0] = 0

    if input_fname.name.split("_")[-1].split(".")[0] in ("T1w", "T2w", "PD"):
        data = im.get_fdata()
        data[data < 0] = 0

    hdr.set_data_dtype(dtype)
    nii = nb.Nifti1Image(
        data if data is not None else im.get_fdata().astype(dtype),
        affine=im.affine,
        header=hdr,
    )

    sform = nii.header.get_sform()
    nii.header.set_sform(sform, 4)
    nii.header.set_qform(sform, 4)

    nii.header.set_xyzt_units(xyz="mm")
    nii.to_filename(str(input_fname))


if __name__ == "__main__":
    in_dir = os.path.abspath("../../dhcp-volumetric-atlas-groupwise")
    out_dir = os.path.abspath("..")
    convert_templates(in_dir, out_dir)
    convert_segmentations(in_dir, out_dir)
    convert_atlas_metadata(in_dir, out_dir)
    write_template_description(out_dir)

    # Sanitize the files
    for root, _, files in os.walk(out_dir):
        for fname in files:
            if fname.endswith(".nii.gz"):
                sanitize(Path(os.path.join(root, fname)))
