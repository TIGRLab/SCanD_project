import json
import logging

logger = logging.getLogger("bin.model_report")


def write_sidecar(fname, metadata):
    with open(fname, "w") as f:
        json.dump(metadata, f, indent=2, default=str)
    logger.info(f"Saved sidecar: {fname}")


def build_run_level_sidecar(
    participant_label,
    task_label,
    space_label,
    dense,
    model_spec_name,
    hrf_model,
    high_pass,
    drift_model,
    smoothing_fwhm=6,
):
    return {
        "subject_label": participant_label,
        "task": task_label,
        "space": space_label,
        "density": dense,
        "model_spec_name": model_spec_name,
        "glm_parameters": {
            "hrf_model": hrf_model,
            "high_pass (Hz)": high_pass,
            "drift_model": drift_model,
            "noise_model": "ar1",
            "smoothing_fwhm (mm)": smoothing_fwhm,
            "t_r (seconds)": None,
        },
        "runs_processed": [],
        "design_matrix_columns": None,
        "contrasts": [],
        "output_files": {
            "effect_maps": [],
            "variance_maps": [],
            "stat_maps": [],
        },
    }


def update_run_level_sidecar(sidecar, run, dm_columns, t_r):
    sidecar["runs_processed"].append(run)
    if sidecar["design_matrix_columns"] is None:
        sidecar["design_matrix_columns"] = dm_columns
    if sidecar["glm_parameters"]["t_r (seconds)"] is None:
        sidecar["glm_parameters"]["t_r (seconds)"] = t_r


def finalize_run_level_sidecar(sidecar, contrasts, effect_maps, variance_maps, stat_maps):
    if contrasts:
        sidecar["contrasts"] = [
            {"name": name, "test": contrast_test}
            for name, _, contrast_test in contrasts
        ]
    sidecar["output_files"]["effect_maps"] = effect_maps
    sidecar["output_files"]["variance_maps"] = variance_maps
    sidecar["output_files"]["stat_maps"] = stat_maps


def build_fixed_effects_sidecar(
    participant_label,
    session,
    task_label,
    contrast,
    n_runs,
    contrast_imgs,
    variance_imgs,
):
    return {
        "subject_label": participant_label,
        "session": session,
        "task": task_label,
        "contrast": contrast,
        "n_runs_combined": n_runs,
        "input_effect_maps": contrast_imgs,
        "input_variance_maps": variance_imgs,
        "outputs": {},
    }
