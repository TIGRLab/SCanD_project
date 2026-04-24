import argparse
import json
import logging
import os
from functools import partial
from pathlib import Path

import nibabel as nb
from bids import BIDSLayout
from src.glm import (
    FirstLevelDesignMatrix,
    FirstLevelModelFit,
    LoadBidsModel,
    load_data,
    plot_dscalar,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

logger = logging.getLogger("main")


def _path_exists(path, parser):
    """Ensure a given path exists."""
    if path is None or not Path(path).exists():
        raise parser.error(f"Path does not exist: <{path}>.")
    return Path(path).absolute()


def _has_session(input_sessions, layout, participant_label):
    """
    Return sessions for a participant, querying BIDS layout only if input_sessions is empty.
    Assumes input_sessions was already normalized with get_value (so empty strings are removed).
    """
    if input_sessions:  # non-empty list
        return input_sessions
    # input_sessions is empty → query BIDS layout
    bids_sessions = layout.get_sessions(subject=participant_label)
    if bids_sessions:
        return bids_sessions
    else:
        return None


def get_value(field, field_name):
    """
    Ensures the field from BIDS stat model has atleast one value
    """

    if field is None:
        if field_name == "session":
            return None
        else:
            raise ValueError(f" The {field_name} field cannot be None")

    if isinstance(field, list):
        if field_name == "session":
            return [s for s in field if s != ""]
        elif len(field) < 1:
            raise ValueError(
                f"The {field_name} field must contain one value. Found: {len(field)} values"
            )
        return field[:]
    elif isinstance(field, str):
        if field_name == "session":
            return [field] if field != "" else []
        return field
    else:
        raise TypeError(
            f"The '{field_name}' field must be a string or list, but got: {type(field)}"
        )


def model_fit(
    bids_dir,
    fmriprep_dir,
    sub,
    task_label,
    session,
    space_label,
    dense,
    specs,
    output_dir,
    drop_duration,
    fwhm=6,
):

    # logger.info(f"Running model_fit for {sub} | task: {task_label} | session: {session}")
    model_instance = FirstLevelModelFit(
        bids_dir,
        fmriprep_dir,
        sub,
        task_label,
        session,
        space_label,
        dense,
        specs,
        output_dir,
        drop_duration,
        fwhm=fwhm,
    )

    effect_maps, variance_maps, t_stat_maps = model_instance.process_and_fit_valid_run()
    if t_stat_maps:
        logger.info(f"Plotting t-stat maps...")
        for map in t_stat_maps:
            outname = map.replace("dscalar.nii", "png")
            data = load_data(map)
            if isinstance(data, nb.Cifti2Image):
                plot_dscalar(data, colorbar=False, output_file=outname)
        logger.info(f"GLM finished successfully for subject: {sub}")
    else:
        logger.warning(f"No t-stat maps found for subject: {sub}")

    return model_instance, effect_maps, variance_maps, t_stat_maps


def main():
    parser = argparse.ArgumentParser(
        description="Fit a General Linear Model (GLM) to surface-based fMRI data preprocessed with fMRIPrep for postprocessing and analysis."
    )
    PathExists = partial(_path_exists, parser=parser)
    parser.add_argument(
        "bids_dir",
        type=PathExists,
        help=(
            "The root folder of the BIDS dataset root directory. "
            "For example, '/path/to/local/data/bids'"
        ),
    )
    parser.add_argument(
        "fmriprep_dir",
        type=PathExists,
        help=(
            "The root folder of fMRIPREP preprocessing derivatives. "
            "For example, '/path/to/local/data/derivatives/fmriprep'"
        ),
    )
    parser.add_argument(
        "--output_dir",
        dest="output_dir",
        type=Path,
        default=None,
        help=(
            "Optional: custom output directory for GLM results. "
            "If not provided, falls back to default relative to fmriprep_dir."
        ),
    )
    parser.add_argument(
        "--participant-label",
        "--participant_label",
        dest="participant_label",
        action="store",
        nargs="*",
        help=(
            "A space-delimited list of participant identifiers, or a single identifier. "
            'The "sub-" prefix can be removed.'
        ),
    )
    parser.add_argument(
        "--model",
        type=str,
        required=True,
        help="Path to the BIDS Stats Model JSON file",
    )
    parser.add_argument(
        "--drop-duration",
        type=float,
        dest="drop_duration",
        required=False,
        default=4,
        help="Number of seconds to discard from the start of the scan (default: 4s)",
    )
    parser.add_argument(
        "--fwhm",
        type=float,
        dest="fwhm",
        required=False,
        default=6,
        help="Smoothing kernel size in mm FWHM applied before GLM fitting (default: 6mm)",
    )
    args = parser.parse_args()
    bids_dir = args.bids_dir
    fmriprep_dir = args.fmriprep_dir
    output_dir = args.output_dir
    model = args.model
    drop_duration = args.drop_duration
    fwhm = args.fwhm

    if not args.participant_label:
        layout = BIDSLayout(bids_dir, derivatives=fmriprep_dir, validate=False)
        participant_label = layout.get_subjects()
    elif isinstance(args.participant_label, str):
        participant_label = [args.participant_label]
    else:
        participant_label = []
        for label in args.participant_label:
            if os.path.isfile(label):  # If it's a file
                with open(label, "r") as file:
                    # Read the file and remove the 'sub-' prefix from each line
                    participant_label.extend(
                        [line.strip().removeprefix("sub-") for line in file.readlines()]
                    )
            else:
                # Process as individual participant label
                participant_label.append(label.removeprefix("sub-"))

    specs = LoadBidsModel(model).specs
    task_label = get_value(specs["Input"]["task"], "task")
    space_label = get_value(specs["Input"]["space"], "space")
    dense = get_value(specs["Input"]["dense"], "dense")
    # Get sessions from specs
    input_sessions = get_value(specs["Input"].get("session"), "session")

    logger.info("Analysis parameters:")
    logger.info(f"  BIDS directory: {bids_dir}")
    logger.info(f"  FMRIPREP directory: {fmriprep_dir}")
    logger.info(f"  Participant ID: {participant_label}")
    logger.info(f"  Task label: {task_label}")
    logger.info(f"  Space label: {space_label}")
    logger.info(f"  Sessions: {input_sessions}")
    logger.info(f"  Dense: {dense}")
    logger.info(f"  Model specifications: {json.dumps(specs, indent=2)}")

    for sub in participant_label:
        if input_sessions:
            sessions = input_sessions
        else:
            logger.info("Session not provided. Checking for available sessions.")
            layout = BIDSLayout(
                bids_dir,
                derivatives=fmriprep_dir,
                validate=False,
                ignore=[f"(?!sub-{sub}).*"],
            )
            sessions = _has_session(input_sessions, layout, sub)

        if not sessions:
            # No sessions — run once with session=None
            sessions = [None]

        for session in sessions:
            try:
                model_instance, effect_maps, variance_maps, _ = model_fit(
                    bids_dir,
                    fmriprep_dir,
                    sub,
                    task_label,
                    session,
                    space_label,
                    dense,
                    specs,
                    output_dir,
                    drop_duration,
                    fwhm=fwhm,
                )

                logger.info("All the beta maps:\n%s", "\n".join(effect_maps))
                logger.info("All the variance maps:\n%s", "\n".join(variance_maps))
                logger.info("Compute fix-effect...")
                model_instance.compute_fix_effect(effect_maps, variance_maps)
            except Exception as e:
                logger.error(
                    f"Error processing session {session} for subject {sub}: {e}"
                )
                continue


if __name__ == "__main__":
    main()
