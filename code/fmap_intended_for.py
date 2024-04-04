# ---
# jupyter:
#   jupytext:
#     text_representation:
#       extension: .py
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.13.8
#   kernelspec:
#     display_name: Python 3
#     language: python
#     name: python3
# ---

# +
from glob import glob
import os
import collections
import json

from bids import BIDSLayout
# -

bids_dir = "data/local/bids"
layout = BIDSLayout(bids_dir, validate=False)

subject_list = layout.get_subjects()

sessions_per_subject = collections.defaultdict(list)

# Iterate over each subject in subject_list
for subject in subject_list:
    sessions = layout.get_sessions(subject=subject)
    sessions_per_subject[subject] = sessions


# Iterate over subjects and sessions
for subject, sessions in sessions_per_subject.items():
    for session in sessions:
        # Process 'dwi' scans
        dwi_fmaps = layout.get(subject=subject, session=session, acquisition="dwi", suffix="epi", extension=".json", return_type="file")
        dwi_files = layout.get(subject=subject, session=session, suffix="dwi", extension=".nii.gz", return_type="file")
        intended_files = ['/'.join((i.split('/')[-3:])) for i in dwi_files]
        if intended_files:
            if len(dwi_fmaps) == 1:
                with open(dwi_fmaps[0], 'r+') as j:
                    json_dict = json.load(j)
                    json_dict_new = json_dict.copy()  # Create a copy of the dictionary
                    json_dict_new['IntendedFor'] = intended_files
                    j.seek(0)
                    json.dump(json_dict_new, j, indent=2)
                    j.truncate()
            else:
                print(dwi_fmaps)

        # Process 'nback' scans
        nback_fmaps = layout.get(subject=subject, session=session, acquisition="nback", suffix="epi", extension=".json", return_type="file")
        nback_files = layout.get(subject=subject, session=session, task="nback", suffix="bold", extension=".nii.gz", return_type="file")
        intended_files = ['/'.join((i.split('/')[-3:])) for i in nback_files]
        if intended_files:
            for nback_fmap in nback_fmaps:
                with open(nback_fmap, 'r+') as j:
                    json_dict = json.load(j)
                    json_dict_new = json_dict.copy()  # Create a copy of the dictionary
                    json_dict_new['IntendedFor'] = intended_files
                    j.seek(0)
                    json.dump(json_dict_new, j, indent=2)
                    j.truncate()

        # Process 'rest' scans
        rest_fmaps = layout.get(subject=subject, session=session, acquisition="rest", suffix="epi", extension=".json", return_type="file")
        rest_files = layout.get(subject=subject, session=session, task="rest", suffix="bold", extension=".nii.gz", return_type="file")
        intended_files = ['/'.join((i.split('/')[-3:])) for i in rest_files]
        if intended_files:
            for rest_fmap in rest_fmaps:
                with open(rest_fmap, 'r+') as j:
                    json_dict = json.load(j)
                    json_dict_new = json_dict.copy()  # Create a copy of the dictionary
                    json_dict_new['IntendedFor'] = intended_files
                    j.seek(0)
                    json.dump(json_dict_new, j, indent=2)
                    j.truncate()

        # Process 'asl' scans
        m0_files = layout.get(subject=subject, session=session, suffix="m0scan", extension=".json", return_type="file")
        asl_files = layout.get(subject=subject, session=session, suffix="asl", extension=".nii.gz", return_type="file")
        intended_files = ['/'.join((i.split('/')[-3:])) for i in asl_files]
        if intended_files and len(m0_files) == 1:
            # Update json file
            with open(m0_files[0], 'r+') as j:
                json_dict = json.load(j)
                json_dict_new = json_dict.copy()  # Create a copy of the dictionary
                json_dict_new['IntendedFor'] = intended_files[0]
                j.seek(0)
                json.dump(json_dict_new, j, indent=2)
                j.truncate()

            # Add aslcontext.tsv file
            aslcontext_file = m0_files[0].replace('_m0scan.json', '_aslcontext.tsv')
            with open(aslcontext_file, 'w+') as f:
                f.write('volume_type\n')
                f.write('deltam\n')
                f.write('m0scan')
        elif intended_files and len(m0_files) != 1:
            print(m0_files)
