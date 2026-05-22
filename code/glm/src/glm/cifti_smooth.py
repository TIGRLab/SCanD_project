import json
import os
from pathlib import Path

from nipype.interfaces.workbench import CiftiSmooth



def get_cifti_surf(fmriprep_dir, participant_label, session=None, ciftify_dir=None):
    import logging

    logger = logging.getLogger(__name__)

    sub_dir = Path(fmriprep_dir) / f"sub-{participant_label}"

    # Multi-session: surfaces at top-level anat/
    # Single-session: surfaces at ses-{session}/anat/
    search_dirs = [sub_dir / "anat"]
    if session:
        search_dirs.append(sub_dir / f"ses-{session}" / "anat")

    pattern_l = f"sub-{participant_label}_*hemi-L_space-fsLR_den-32k_midthickness.surf.gii"
    pattern_r = f"sub-{participant_label}_*hemi-R_space-fsLR_den-32k_midthickness.surf.gii"

    l_surf = r_surf = None
    for anat_dir in search_dirs:
        if not anat_dir.exists():
            continue
        l_candidates = sorted(anat_dir.glob(pattern_l))
        r_candidates = sorted(anat_dir.glob(pattern_r))
        if l_candidates and r_candidates:
            l_surf = l_candidates[0]
            r_surf = r_candidates[0]
            break

    if l_surf is None or r_surf is None:
        if ciftify_dir:
            ciftify_sub = (
                f"sub-{participant_label}_ses-{session}.long.sub-{participant_label}"
                if session
                else f"sub-{participant_label}"
            )
            ciftify_surf_dir = Path(ciftify_dir) / ciftify_sub / "MNINonLinear" / "fsaverage_LR32k"
            surf_l = ciftify_surf_dir / f"{ciftify_sub}.L.midthickness.32k_fs_LR.surf.gii"
            surf_r = ciftify_surf_dir / f"{ciftify_sub}.R.midthickness.32k_fs_LR.surf.gii"
            if surf_l.exists() and surf_r.exists():
                logger.info(
                    f"sub-{participant_label}: using ciftify surfaces from {ciftify_surf_dir}"
                )
                return str(surf_l), str(surf_r)
            logger.warning(
                f"sub-{participant_label}: ciftify surfaces not found at {ciftify_surf_dir}"
            )
        raise FileNotFoundError(
            f"No fsLR 32k midthickness surface found for sub-{participant_label}. "
            f"Searched fMRIPrep: {[str(d) for d in search_dirs]}. "
            f"Searched ciftify: {ciftify_surf_dir if ciftify_dir else 'not provided'}."
        )

    return str(l_surf), str(r_surf)


def wb_smooth(in_cifti, l_surf, r_surf, fwhm):
    import logging

    logger = logging.getLogger(__name__)
    """
    Smooth a CIFTI dtseries file using Connectome-Workbench-1.4.2 via Nipype
    Return the smoothed file
    """

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
