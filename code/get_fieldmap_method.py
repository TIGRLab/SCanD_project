#!/usr/bin/env python3
"""
extract_fmap_methods.py

Extracts fieldmap methods from FMRIPREP _desc-summary_bold.html files
and outputs a CSV with columns: subject, session, task, run, fieldmap_method.
"""

import argparse
import csv
import re
from pathlib import Path
from bs4 import BeautifulSoup

def parse_args():
    parser = argparse.ArgumentParser(
        description="Extract fieldmap methods from FMRIPREP HTML summary files"
    )
    parser.add_argument(
        "-i", "--input-dir",
        required=True,
        help="Path to FMRIPREP derivatives directory"
    )
    parser.add_argument(
        "-o", "--output-csv",
        default=None,
        help="Path to output CSV file (default: <input-dir>/fieldmap_methods.csv)"
    )
    return parser.parse_args()

def extract_fieldmap_method(html_path):
    """Parse a single HTML file and extract the susceptibility distortion correction method."""
    with open(html_path, "r") as f:
        soup = BeautifulSoup(f.read(), "html.parser")

    li = soup.find(
        "li",
        string=lambda s: s and "Susceptibility distortion correction" in s
    )

    if li:
        method = li.text.strip().replace("Susceptibility distortion correction: ", "")
    else:
        method = "NOT FOUND"
    return method

def main():
    args = parse_args()
    fmriprep_path = Path(args.input_dir)

    # Set default output CSV if not provided
    output_csv = Path(args.output_csv) if args.output_csv else fmriprep_path / "fieldmap_methods.csv"

    # Grab all HTML files recursively
    html_files = sorted(fmriprep_path.rglob("**/*_desc-summary_bold.html"))

    results = []

    # Regex for BIDS entities (handles optional ses/run)
    bids_regex = re.compile(
        r"sub-(?P<sub>[^_]+)"
        r"(?:_ses-(?P<ses>[^_]+))?"
        r"_task-(?P<task>[^_]+)"
        r"(?:_run-(?P<run>\d+))?"
        r"_desc-summary_bold\.html"
    )

    for html_path in html_files:
        filename = html_path.name
        m = bids_regex.match(filename)
        if not m:
            continue

        sub = m.group("sub")
        ses = m.group("ses") if m.group("ses") else "NA"
        task = m.group("task")
        run = m.group("run") if m.group("run") else "NA"

        method = extract_fieldmap_method(html_path)
        results.append([sub, ses, task, run, method])

    # Write CSV
    with open(output_csv, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["subject", "session", "task", "run", "fieldmap_method"])
        writer.writerows(results)

    print(f"Done! Output written to {output_csv}")

if __name__ == "__main__":
    main()
