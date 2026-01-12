#%%
from pathlib import Path
import fnmatch
import yaml
from collections import defaultdict
from bids import BIDSLayout
import pandas as pd
import argparse
from functools import partial
import os
import json

def validate_bids_config(config):
	# Validate query blocks
	if "bold_query" in config and "fmap_fmri_query" not in config:
		raise ValueError("bold_query requires fmap_fmri_query to be defined")

	if "dwi_query" in config and "fmap_dwi_query" not in config:
		raise ValueError("dwi_query requires fmap_dwi_query to be defined")

	# Validate query format (datatype/suffix/extension)
	for query_name in ["fmap_fmri_query", "fmap_dwi_query", "bold_query", "dwi_query"]:
		if query_name not in config:
			continue  # queries are optional
		query = config[query_name]

		# Basic required keys
		for key in ["datatype", "suffix", "extension"]:
			if key not in query:
				raise ValueError(f"Missing '{key}' in {query_name}")

		# Optional keys
		for optional in ["task", "acquisition"]:
			value = query.get(optional)
			if value is None:
				continue
			if isinstance(value, str):
				continue
			if isinstance(value, list) and all(isinstance(v, str) for v in value):
				continue
			raise ValueError(
				f"'{optional}' in {query_name} must be a string, list of strings, or null"
			)

	# Validate fmap-to-image mappings
	mapping_sections = []

	if "fmap_to_bold" in config:
		mapping_sections.append(("fmap_to_bold", "bold_keys"))

	if "fmap_to_dwi" in config:
		mapping_sections.append(("fmap_to_dwi", "dwi_keys"))

	for section_name, key_name in mapping_sections:
		mapping = config[section_name]

		if not isinstance(mapping, list) or not mapping:
			raise ValueError(f"{section_name} must be a non-empty list of dicts")

		for i, entry in enumerate(mapping):
			if "fmap" not in entry:
				raise ValueError(f"{section_name}[{i}] missing 'fmap'")
			if not isinstance(entry["fmap"], str):
				raise ValueError(f"'fmap' in {section_name}[{i}] must be a string")

			# optional key: bold_keys (string, list, or None)
			if key_name in entry:
				val = entry[key_name]
				if isinstance(val, str):
					entry[key_name] = [val]
				elif isinstance(val, list):
					if not all(isinstance(v, str) for v in val):
						raise ValueError(
							f"All elements of '{key_name}' in {section_name}[{i}] must be strings"
						)
				elif val is not None:
					raise ValueError(
						f"'{key_name}' in {section_name}[{i}] must be string, list, or None"
					)

	print("✅ YAML configuration passed validation")

def get_bids_files(layout, subject, session, query, label):
	"""Fetch BIDS files for a modality, warn if missing."""
	if not query:
		print(f"  NOTE: No query defined for {label}, skipping.")
		return []

	files = layout.get(subject=subject, session=session, **query)

	if not files:
		print(f"  WARNING: No {label} files found, skipping...")
	return files

def update_intendedfor_from_yaml(fmap_files, img_files, fmap_to_img_map, bids_dir, subject):
	"""
	Update fieldmap JSONs with IntendedFor using a YAML mapping.
	
	Supports run-based or task-based matching, wildcard fieldmap names, and run-less/task-less cases.

	Parameters
	----------
	fmap_files : list
		List of fieldmap files (BIDSFile objects)
	img_files : list
		List of target files (BIDSFile objects, e.g., BOLD or DWI)
	fmap_to_img_map : list of dicts
		YAML mapping in the format:
		[
			{"fmap": "acq-rest_dir-*_run-01_epi.json", "bold_keys": ["run-01"]},
			{"fmap": "acq-rest_dir-AP_epi.json", "bold_keys": ["rest"]},
			...
		]
		- `bold_keys` can contain run numbers, task names, or be None for run-less/task-less
	bids_dir : Path or str
		Path to the BIDS dataset root
	subject : str
		Subject ID, e.g., "CMH00000046"
	"""

	for mapping in fmap_to_img_map:
		fmap_pattern = mapping["fmap"]
		img_keys = mapping.get("bold_keys")  # list of runs, tasks, or None

		for fmap_file in fmap_files:
			# Match fieldmap filename using wildcard
			if fnmatch.fnmatch(Path(fmap_file.path).name, f"*{fmap_pattern}*"):
				intended_for = []

				if not img_keys:  # run-less/task-less → include all images
					for img in img_files:
						rel_path = str(Path(img.path).relative_to(Path(bids_dir) / f"sub-{subject}"))
						intended_for.append(rel_path)
				else:  # run/task-specific
					for key in img_keys:
						for img in img_files:
							if key in img.filename:
								rel_path = str(Path(img.path).relative_to(Path(bids_dir) / f"sub-{subject}"))
								intended_for.append(rel_path)

				# Update the fieldmap JSON once
				fmap_json_path = Path(fmap_file.path)
				with open(fmap_json_path, "r+") as f:
					fmap_json = json.load(f)
					fmap_json["IntendedFor"] = intended_for
					f.seek(0)
					json.dump(fmap_json, f, indent=4)
					f.truncate()

				print(f"Updated {fmap_json_path.name} with IntendedFor: {intended_for}")

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
		"--config",
		type=str,
		required=True,
		help="Path to the YAML config file",
	)
	args = parser.parse_args()
	bids_dir = args.bids_dir
	participant_label = args.participant_label
	config = args.config

	with open(config, "r") as f:
		config = yaml.safe_load(f)
	
	validate_bids_config(config)
	fmap_fmri_query = config.get("fmap_fmri_query", {})
	fmap_dwi_query = config.get("fmap_dwi_query", {})
	bold_query = config.get("bold_query", {})
	dwi_query = config.get("dwi_query", {})
	fmap_to_bold = config.get("fmap_to_bold", {})
	fmap_to_dwi = config.get("fmap_to_dwi", {})
	
	if not participant_label:
		layout = BIDSLayout(bids_dir, validate=False)
		participant_label = layout.get_subjects()
	else:
		cleaned = []
		for label in participant_label:
			if os.path.isfile(label):
				# File with participant IDs
				with open(label, "r") as f:
					cleaned.extend(
						[line.strip().removeprefix("sub-") for line in f.readlines() if line.strip() and not line.lower().startswith("participant_id")]
					)
			else:
				# A normal participant label
				cleaned.append(label.removeprefix("sub-"))

		participant_label = cleaned
	for sub in participant_label:
		layout = BIDSLayout(
				bids_dir,
				validate=False,
				ignore=[f"(?!sub-{sub}).*"],
			)
		sessions = layout.get_sessions() 
		for session in sessions:
			fmap_fmri_files = get_bids_files(layout, sub, session, fmap_fmri_query, "fMRI fieldmaps")
			fmap_dwi_files = get_bids_files(layout, sub, session, fmap_dwi_query, "DWI fieldmaps")
			bold_files = get_bids_files(layout, sub, session, bold_query, "BOLD")
			dwi_files = get_bids_files(layout, sub, session, dwi_query, "DWI")
			update_intendedfor_from_yaml(fmap_fmri_files,bold_files,fmap_to_bold, bids_dir, sub)
			update_intendedfor_from_yaml(fmap_dwi_files,dwi_files,fmap_to_dwi, bids_dir, sub)

if __name__ == "__main__":
	main()