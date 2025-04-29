import argparse
import json
import logging
import os
from functools import partial
from pathlib import Path

import nibabel as nb
from bids import BIDSLayout
from bin import (
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
        "--drop-dummy-TRs",
        type=int,
        required=False,
        help="Discard the number of TR's from the begginning of the scan",
    )
    args = parser.parse_args()
    bids_dir = args.bids_dir
    fmriprep_dir = args.fmriprep_dir
    model = args.model

    if not args.participant_label:
        layout = BIDSLayout(bids_dir, derivatives=fmriprep_dir, validate=False)
        participant_label = layout.get_subjects()
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
    specs = LoadBidsModel(model)._ensure_model()
    task_label = specs["Input"]["task"][0]
    space_label = specs["Input"]["space"]
    sessions = specs["Input"]["session"]
    dense = specs["Input"]["dense"]
    # logger.info(
    #     f" bids_dir: {bids_dir, fmriprep_dir, participant_label, specs, task_label, space_label, sessions, dense}"
    # )
    logger.info("Analysis parameters:")
    logger.info(f"  BIDS directory: {bids_dir}")
    logger.info(f"  FMRIPREP directory: {fmriprep_dir}")
    logger.info(f"  Participant ID: {participant_label}")
    logger.info(f"  Task label: {task_label}")
    logger.info(f"  Space label: {space_label}")
    logger.info(f"  Sessions: {sessions}")
    logger.info(f"  Dense: {dense}")
    logger.info(f"  Model specifications: {json.dumps(specs, indent=2)}")

    for sub in participant_label:
        if not isinstance(sessions, (str, list)):
            raise ValueError(f"sessions must be a string or a list")
        if isinstance(sessions, list):
            for session in sessions:
                model_instance = FirstLevelModelFit(
                    bids_dir,
                    fmriprep_dir,
                    sub,
                    task_label,
                    session,
                    space_label,
                    dense,
                    model,
                )

                # Fitting the model
                logger.info(
                    f"Found match runs: {[run for run in model_instance.match_runs]} for subject: {sub}"
                )
                beta_maps = model_instance.process_and_fit_valid_run()
        elif isinstance(sessions, str):
            model_instance = FirstLevelModelFit(
                bids_dir,
                fmriprep_dir,
                sub,
                task_label,
                sessions,
                space_label,
                dense,
                model,
            )

            # Fitting the model
            logger.info(
                f"Found match runs: {[run for run in model_instance.match_runs]} for subject: {sub}"
            )
            beta_maps = model_instance.process_and_fit_valid_run()

        if beta_maps:
            logger.info(f"Plotting the betamap....")
            for map in beta_maps:
                outname = map.replace("dscalar.nii", "png")
                data = load_data(map)

                if isinstance(data, nb.Cifti2Image):
                    plot_dscalar(data, colorbar=False, output_file=outname)
            logger.info(f"glm finished successfully")
        else:
            logger.warning(f"No betamaps found")


if __name__ == "__main__":
    main()
