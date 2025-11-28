import json
import os
from pathlib import Path

from nipype.interfaces.workbench import CiftiSmooth


def get_cifti_surf(ciftify_dir, participant_label, session=None):
    subj_dir = (
        Path(ciftify_dir)
        / f"sub-{participant_label}_ses-{session}.long.sub-{participant_label}"
        / "MNINonLinear"
        / "fsaverage_LR32k"
    )
    # left/right surfaces
    l_surf = (
        subj_dir
        / f"sub-{participant_label}_ses-{session}.long.sub-{participant_label}.L.midthickness.32k_fs_LR.surf.gii"
    )
    r_surf = (
        subj_dir
        / f"sub-{participant_label}_ses-{session}.long.sub-{participant_label}.R.midthickness.32k_fs_LR.surf.gii"
    )
    if not l_surf.exists():
        raise FileNotFoundError(f"Missing left surface file: {l_surf}")
    if not r_surf.exists():
        raise FileNotFoundError(f"Missing left surface file: {l_surf}")
    return str(l_surf), str(r_surf)


def wb_smooth(in_cifti, l_surf, r_surf, fwhm=6):
    import logging

    logger = logging.getLogger(__name__)
    """
    Smooth a CIFTI dtseries file using Connectome-Workbench-1.4.2 via Nipype
    Return the smoothed file
    """
    # module_dir = os.path.dirname(os.path.abspath(__file__))
    # template_dir = os.path.join(module_dir, "..", "templates")
    # left_surf = os.path.join(template_dir, "L.midthickness.32k_fs_LR.surf.gii").format
    # right_surf = os.path.join(template_dir, "L.midthickness.32k_fs_LR.surf.gii").format
    base, ext = os.path.splitext(in_cifti)
    out_file = base.replace("_bold", f"_desc-Smoothed_bold") + ext
    json_out = base.replace("_bold.dtseries", f"_desc-Smoothed_bold.json")
    smooth = CiftiSmooth()

    smooth.inputs.in_file = in_cifti
    smooth.inputs.sigma_surf = fwhm
    smooth.inputs.sigma_vol = fwhm
    smooth.inputs.direction = "COLUMN"
    smooth.inputs.left_surf = l_surf
    smooth.inputs.right_surf = r_surf
    smooth.inputs.out_file = out_file
    smooth.inputs.args = "-fwhm"
    logger.info(f"Running command: {smooth.cmdline}")
    output = smooth.run()
    output_path = output.outputs.out_file
    smooth.save_inputs_to_json(json_out)
    return output_path
