from glob import glob
import os
import collections
import json

from bids import BIDSLayout

bids_dir = "data/local/bids"
layout = BIDSLayout(bids_dir, validate=False)

subject_list = layout.get_subjects()
sessions = layout.get_sessions()  # Dynamically get sessions

# Handle session-less data
if not sessions:
    sessions = [None]  

for session in sessions:
    for subject in subject_list:
        # Check if session exists and create session arguments
        session_kwargs = {"session": session} if session else {}
        
        dwi_fmaps = layout.get(subject=subject, acquisition="dwi", suffix="epi", extension=".json", return_type="file", **session_kwargs)
        dwi_files = layout.get(subject=subject, suffix="dwi", extension=".nii.gz", return_type="file", **session_kwargs)
        
        intended_files = ['/'.join((i.split('/')[-3:])) for i in dwi_files]
        if not intended_files:
            continue
        if len(dwi_fmaps) == 1:
            with open(dwi_fmaps[0], 'r+') as j:
                json_dict = json.load(j)
                json_dict_new = json_dict
                json_dict_new['IntendedFor'] = intended_files
                j.seek(0)
                json.dump(json_dict_new, j, indent=2)
                j.truncate()
        else:
            print(dwi_fmaps)

    for subject in subject_list:
        nback_fmaps = layout.get(subject=subject, acquisition="nback", suffix="epi", extension=".json", return_type="file", **session_kwargs)
        nback_files = layout.get(subject=subject, task="nback", suffix="bold", extension=".nii.gz", return_type="file", **session_kwargs)
        intended_files = ['/'.join((i.split('/')[-3:])) for i in nback_files]
        if not intended_files:
            continue
        for nback_fmap in nback_fmaps:
            with open(nback_fmap, 'r+') as j:
                json_dict = json.load(j)
                json_dict_new = json_dict
                json_dict_new['IntendedFor'] = intended_files
                j.seek(0)
                json.dump(json_dict_new, j, indent=2)
                j.truncate()

    for subject in subject_list:
        rest_fmaps = layout.get(subject=subject, acquisition="rest", suffix="epi", extension=".json", return_type="file", **session_kwargs)
        rest_files = layout.get(subject=subject, task="rest", suffix="bold", extension=".nii.gz", return_type="file", **session_kwargs)
        intended_files = ['/'.join((i.split('/')[-3:])) for i in rest_files]
        if not intended_files:
            continue
        for rest_fmap in rest_fmaps:
            with open(rest_fmap, 'r+') as j:
                json_dict = json.load(j)
                json_dict_new = json_dict
                json_dict_new['IntendedFor'] = intended_files
                j.seek(0)
                json.dump(json_dict_new, j, indent=2)
                j.truncate()

    for subject in subject_list:
        dwi_fmaps = layout.get(subject=subject,  acquisition="dwitopup", suffix="epi", extension=".json", return_type="file", **session_kwargs)
        dwi_files = layout.get(subject=subject,  suffix="dwi", extension=".nii.gz", return_type="file", **session_kwargs)
        intended_files = ['/'.join((i.split('/')[-3:])) for i in dwi_files]
        if not intended_files:
            continue
        if len(dwi_fmaps) == 1:
            with open(dwi_fmaps[0], 'r+') as j:
                json_dict = json.load(j)
                json_dict_new = json_dict
                json_dict_new['IntendedFor'] = intended_files
                j.seek(0)
                json.dump(json_dict_new, j, indent=2)
                j.truncate()
        else:
            print(dwi_fmaps)

    for subject in subject_list:
        nback_fmaps = layout.get(subject=subject, acquisition="functopup", suffix="epi", extension=".json", return_type="file", **session_kwargs)
        nback_files = layout.get(subject=subject, task="rest", suffix="bold", extension=".nii.gz", return_type="file", **session_kwargs)
        intended_files = ['/'.join((i.split('/')[-3:])) for i in nback_files]
        if not intended_files:
            continue
        for nback_fmap in nback_fmaps:
            with open(nback_fmap, 'r+') as j:
                json_dict = json.load(j)
                json_dict_new = json_dict
                json_dict_new['IntendedFor'] = intended_files
                j.seek(0)
                json.dump(json_dict_new, j, indent=2)
                j.truncate()

    for subject in subject_list:
        m0_files = layout.get(subject=subject, suffix="m0scan", extension=".json", return_type="file", **session_kwargs)
        asl_files = layout.get(subject=subject, suffix="asl", extension=".nii.gz", return_type="file", **session_kwargs)
        intended_files = ['/'.join((i.split('/')[-3:])) for i in asl_files]
        if not intended_files:
            continue
        if len(m0_files) == 1:
            # update json file
            with open(m0_files[0], 'r+') as j:
                json_dict = json.load(j)
                json_dict_new = json_dict
                json_dict_new['IntendedFor'] = intended_files[0]
                j.seek(0)
                json.dump(json_dict_new, j, indent=2)
                j.truncate()
            
            # add aslcontext.tsv file
            aslcontext_file = m0_files[0].replace('_m0scan.json','_aslcontext.tsv')
            with open(aslcontext_file, 'w+') as f:
                f.write('volume_type\n')
                f.write('deltam\n')
                f.write('m0scan')
             
        else:
            print(m0_files)
