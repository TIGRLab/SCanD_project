#!/usr/bin/env python3

import argparse
import csv
import json
import shutil
from pathlib import Path
from tempfile import NamedTemporaryFile


def detect_method_for_session(session_dir: Path) -> str:
    json_files = sorted(session_dir.glob("fmap/*desc-preproc_fieldmap.json"))

    if not json_files:
        return "no fmri"

    methods = set()

    for json_file in json_files:
        try:
            with open(json_file, "r") as f:
                data = json.load(f)
        except Exception as e:
            print(f"Warning: could not read {json_file}: {e}")
            continue

        raw_sources = data.get("RawSources", [])
        if isinstance(raw_sources, str):
            raw_sources = [raw_sources]

        for src in raw_sources:
            src = str(src).lower()

            if "/fmap/" in src:
                methods.add("PEPOLAR (TOPUP)")

            if "/func/" in src:
                methods.add("synthetic fieldmaps")

    if not methods:
        return "unknown"

    ordered = [m for m in ["PEPOLAR (TOPUP)", "synthetic fieldmaps"] if m in methods]
    return ";".join(ordered)


def load_existing(output_tsv: Path) -> dict:
    data = {}

    if not output_tsv.exists():
        return data

    with open(output_tsv, "r", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            pid = row.get("participant_id", "").strip()
            ses = row.get("session_id", "").strip()
            method = row.get("fmriprep_method", "").strip()

            if pid and ses:
                data[(pid, ses)] = method

    return data


def write_output(output_tsv: Path, data: dict):
    output_tsv.parent.mkdir(parents=True, exist_ok=True)

    tmp = NamedTemporaryFile("w", delete=False, newline="", dir=output_tsv.parent)
    tmp_path = Path(tmp.name)

    try:
        with tmp as f:
            writer = csv.DictWriter(
                f,
                fieldnames=["participant_id", "session_id", "fmriprep_method"],
                delimiter="\t",
            )
            writer.writeheader()

            for pid, ses in sorted(data):
                writer.writerow(
                    {
                        "participant_id": pid,
                        "session_id": ses,
                        "fmriprep_method": data[(pid, ses)],
                    }
                )

        shutil.move(tmp_path, output_tsv)

    finally:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fmriprep-root", required=True)
    parser.add_argument("--output-tsv", required=True)
    parser.add_argument("--participant-ids", nargs="*", default=None)

    args = parser.parse_args()

    fmriprep_root = Path(args.fmriprep_root)
    output_tsv = Path(args.output_tsv)

    existing = load_existing(output_tsv)

    if args.participant_ids:
        subjects = [fmriprep_root / pid for pid in args.participant_ids]
    else:
        subjects = [p for p in fmriprep_root.iterdir() if p.is_dir() and p.name.startswith("sub-")]

    updated = 0

    for subject_dir in subjects:
        if not subject_dir.exists():
            continue

        pid = subject_dir.name
        session_dirs = [
            p for p in subject_dir.iterdir()
            if p.is_dir()
            and p.name.startswith("ses-")
            and "-" not in p.name[4:]
        ]

        for session_dir in session_dirs:
            ses = session_dir.name
            existing[(pid, ses)] = detect_method_for_session(session_dir)
            updated += 1

    write_output(output_tsv, existing)

    print(f"Updated {updated} subject/session rows")
    print(f"Saved to: {output_tsv}")


if __name__ == "__main__":
    main()
