#%%
from pathlib import Path
import fnmatch
import logging
import warnings
import yaml
from bids import BIDSLayout
import argparse
from functools import partial
import os
import json

warnings.filterwarnings("ignore", category=UserWarning, module="bids")


class _Formatter(logging.Formatter):
	def format(self, record):
		msg = record.getMessage()
		if record.levelno >= logging.WARNING:
			# WARN lines: "  WARN  message", continuation indented to match message start
			return "  WARN  " + ("\n        ").join(msg.splitlines())
		else:
			# INFO/DEBUG lines: simple 2-space indent, clearly separate from WARN continuation
			return "  " + ("\n  ").join(msg.splitlines())


_handler = logging.StreamHandler()
_handler.setFormatter(_Formatter())
logging.root.handlers = [_handler]
logging.root.setLevel(logging.INFO)
log = logging.getLogger(__name__)


def _short_name(filename):
	"""Strip sub-X_ses-Y_ prefix and file extension for compact display."""
	parts = [p for p in filename.split("_") if not p.startswith(("sub-", "ses-"))]
	name = "_".join(parts)
	for ext in (".nii.gz", ".json", ".nii"):
		if name.endswith(ext):
			name = name[: -len(ext)]
			break
	for suffix in ("_bold", "_dwi"):
		if name.endswith(suffix):
			name = name[: -len(suffix)]
			break
	return name


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

		# Accept either a flat list (all sessions) or a session-keyed dict
		if isinstance(mapping, list):
			entries_to_validate = mapping
		elif isinstance(mapping, dict):
			entries_to_validate = []
			for ses_key, ses_entries in mapping.items():
				if not isinstance(ses_entries, list) or not ses_entries:
					raise ValueError(f"{section_name}[{ses_key}] must be a non-empty list of dicts")
				entries_to_validate.extend(ses_entries)
		else:
			raise ValueError(f"{section_name} must be a list or a session-keyed dict")

		for i, entry in enumerate(entries_to_validate):
			if "fmap" not in entry:
				raise ValueError(f"{section_name}[{i}] missing 'fmap'")
			if not isinstance(entry["fmap"], str):
				raise ValueError(
					f"'fmap' in {section_name}[{i}] must be a string, "
					f"got {type(entry['fmap']).__name__}: {entry['fmap']!r}"
				)

			# bold_keys/dwi_keys is required — every fieldmap must map to specific images
			if key_name not in entry or entry[key_name] is None:
				raise ValueError(f"{section_name}[{i}] missing required '{key_name}'")
			val = entry[key_name]
			if isinstance(val, str):
				entry[key_name] = [val]
			elif isinstance(val, list):
				if not val:
					raise ValueError(f"'{key_name}' in {section_name}[{i}] must not be empty")
				if not all(isinstance(v, str) for v in val):
					raise ValueError(
						f"All elements of '{key_name}' in {section_name}[{i}] must be strings"
					)
			else:
				raise ValueError(
					f"'{key_name}' in {section_name}[{i}] must be a string or list of strings"
				)

	log.info("Config validated successfully")


def get_bids_files(layout, subject, session, query, label):
	"""Fetch BIDS files for a modality, warn if missing."""
	if not query:
		log.debug("No query defined for %s, skipping.", label)
		return []

	files = layout.get(subject=subject, session=session, **query)

	if not files:
		log.warning("No %s files found for sub-%s ses-%s", label, subject, session)
	return files


def update_intendedfor_from_yaml(fmap_files, img_files, fmap_to_img_map, bids_dir, subject):
	"""
	Update fieldmap JSONs with IntendedFor using a YAML mapping.

	Parameters
	----------
	fmap_files : list
		List of fieldmap files (BIDSFile objects)
	img_files : list
		List of target files (BIDSFile objects, e.g., BOLD or DWI)
	fmap_to_img_map : list of dicts
		YAML mapping entries, each with 'fmap' and 'bold_keys'/'dwi_keys'
	bids_dir : Path or str
		Path to the BIDS dataset root
	subject : str
		Subject ID, e.g., "CMH00000046"
	"""
	if not fmap_to_img_map or not fmap_files or not img_files:
		return

	mapped_imgs = set()

	for mapping in fmap_to_img_map:
		fmap_pattern = mapping["fmap"]

		matched_fmaps = [
			f for f in fmap_files
			if fnmatch.fnmatch(Path(f.path).name, f"*{fmap_pattern}*")
		]

		if not matched_fmaps:
			log.warning("No fieldmap matched pattern '%s'", fmap_pattern)
			continue

		img_keys = mapping.get("bold_keys") or mapping.get("dwi_keys")

		for fmap_file in matched_fmaps:
			intended_for = []
			missing_keys = []

			for key in img_keys:
				key_matches = [img for img in img_files if key in img.filename]
				if not key_matches:
					missing_keys.append(key)
					continue
				for img in key_matches:
					rel_path = str(Path(img.path).relative_to(Path(bids_dir) / f"sub-{subject}"))
					intended_for.append(rel_path)
					mapped_imgs.add(img.path)

			if not intended_for:
				log.warning(
					"No images matched keys %s for '%s' — JSON not modified",
					img_keys, Path(fmap_file.path).name,
				)
				continue

			fmap_json_path = Path(fmap_file.path)
			with open(fmap_json_path, "r+") as f:
				fmap_json = json.load(f)
				fmap_json["IntendedFor"] = intended_for
				f.seek(0)
				json.dump(fmap_json, f, indent=4)
				f.truncate()

			fmap_short = _short_name(fmap_json_path.name)
			tree = "\n".join(
				f"    {'└──' if i == len(intended_for) - 1 else '├──'} {p}"
				for i, p in enumerate(intended_for)
			)
			log.info("Writing 'IntendedFor' in %s with %d file(s):\n%s", fmap_short, len(intended_for), tree)

			if missing_keys:
				available = ", ".join(_short_name(img.filename) for img in img_files)
				for key in missing_keys:
					log.warning(
						"Key '%s' matched no image files.\n"
						"Available nii image files for: %s\n"
						"Check: typo in bold_keys/bold_query, mismatched task name, or missing scan",
						key, available,
					)

	unmapped = [img for img in img_files if img.path not in mapped_imgs]
	if unmapped:
		names = ", ".join(_short_name(img.filename) for img in unmapped)
		log.warning(
			"Image file(s) not mapped to any fieldmap: %s\n"
			"Check: the fieldmap pattern in the config may not match any existing fieldmap file",
			names,
		)


def _resolve_mapping(fmap_map, session):
	"""Return the mapping list for the given session.

	If fmap_map is a plain list, it applies to all sessions.
	If it is a session-keyed dict, return the entry for this session and warn if absent.
	"""
	if isinstance(fmap_map, list):
		return fmap_map
	# session-keyed dict: keys may be bare IDs ("01") or prefixed ("ses-01")
	for key in (session, f"ses-{session}", session.removeprefix("ses-")):
		if key in fmap_map:
			return fmap_map[key]
	log.warning(
		"Session '%s' not in config — IntendedFor will not be updated.\n"
		"Configured: %s",
		session, ", ".join(fmap_map.keys()),
	)
	return []


def _path_exists(path, parser):
	"""Ensure a given path exists."""
	if path is None or not Path(path).exists():
		raise parser.error(f"Path does not exist: <{path}>.")
	return Path(path).absolute()


def main():
	parser = argparse.ArgumentParser(
		description="Populate the IntendedFor field in fieldmap JSON sidecars with the intended functional or diffusion images."
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
	parser.add_argument(
		"--verbose", "-v",
		action="store_true",
		help="Show debug messages (e.g. skipped modalities)",
	)
	args = parser.parse_args()

	if args.verbose:
		logging.getLogger().setLevel(logging.DEBUG)

	bids_dir = args.bids_dir
	participant_label = args.participant_label
	config = args.config

	with open(config, "r") as f:
		config = yaml.safe_load(f)

	validate_bids_config(config)
	fmap_fmri_query = config.get("fmap_fmri_query", {})
	fmap_dwi_query  = config.get("fmap_dwi_query", {})
	bold_query      = config.get("bold_query", {})
	dwi_query       = config.get("dwi_query", {})
	fmap_to_bold    = config.get("fmap_to_bold", [])
	fmap_to_dwi     = config.get("fmap_to_dwi", [])

	if not participant_label:
		layout = BIDSLayout(bids_dir, validate=False)
		participant_label = layout.get_subjects()
	else:
		cleaned = []
		for label in participant_label:
			if os.path.isfile(label):
				with open(label, "r") as f:
					cleaned.extend(
						[line.strip().removeprefix("sub-") for line in f.readlines()
						 if line.strip() and not line.lower().startswith("participant_id")]
					)
			else:
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
			print(f"\n── sub-{sub} | ses-{session} ──")
			fmap_fmri_files     = get_bids_files(layout, sub, session, fmap_fmri_query, "fMRI fieldmaps")
			fmap_dwi_files      = get_bids_files(layout, sub, session, fmap_dwi_query,  "DWI fieldmaps")
			bold_files          = get_bids_files(layout, sub, session, bold_query,       "BOLD")
			dwi_files           = get_bids_files(layout, sub, session, dwi_query,        "DWI")
			session_fmap_to_bold = _resolve_mapping(fmap_to_bold, session)
			session_fmap_to_dwi  = _resolve_mapping(fmap_to_dwi,  session)
			update_intendedfor_from_yaml(fmap_fmri_files, bold_files, session_fmap_to_bold, bids_dir, sub)
			update_intendedfor_from_yaml(fmap_dwi_files,  dwi_files,  session_fmap_to_dwi,  bids_dir, sub)


if __name__ == "__main__":
	main()
