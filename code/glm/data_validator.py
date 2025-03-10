from nilearn.glm.first_level import first_level_from_bids
from bids import BIDSLayout
import os
from warnings import warn
# from nilearn.glm.first_level.first_level import _get_processed_imgs, _check_bids_image_list, _make_bids_files_filter, infer_slice_timing_start_time_from_dataset
from nilearn.interfaces.bids.utils import bids_entities
from nilearn.interfaces.bids.query import get_bids_files,_get_metadata_from_bids
import logging 

# Setup logging configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class BIDSDataValidator:
    def __init__(self, bids_dir, task_label):
        self.bids_dir = bids_dir
        self.task_label = task_label
        self.layout = BIDSLayout(bids_dir, is_derivative=True, validate=False)
    
    def match_bold_and_events(self, participant_labels=None):
        """

        Check if BOLD and events files match for each participant.

        Args.
            participant_albel (list, optional): List of participant IDs to check.
                                                Default to all participants in the dataset
        Returns:
            list: A list of valid participants with matching BOLD and event files.
        """
        

        if not participant_labels:
            participant_labels = self.layout.get_subjects()
            logger.info(f"Retrieved subjects: {participant_labels}")
        elif isinstance(participant_labels, str):
            participant_labels = [participant_labels]
        valid_participants = []

        for sub in participant_labels:
            sub_imgs = self.layout.get(extension='nii.gz', task=self.task_label, subject=sub)
            sub_events_files = self.layout.get(extension='tsv', task=self.task_label, subject=sub)

            if len(sub_imgs) == len(sub_events_files):
                valid_participants.append(sub)  # Keep only valid participants
            else:
                logger.info(f"Found {len(sub_events_files)} task events file(s) found for {len(sub_imgs)} bold file(s). "
                                f"Same number of event files as the number of runs is expected.\nSkipping {sub}...")
        return valid_participants