#!/usr/bin/env python3
import argparse
from pathlib import Path
import re
import csv
from bs4 import BeautifulSoup

def extract_sdc(qsiprep_root, participants):
    rows = []
    seen = set()

    for sub in participants:
        html_file = Path(qsiprep_root) / f"{sub}.html"

        if not html_file.exists():
            rows.append({
                "participant_id": sub,
                "session_id": "",
                "qsiprep_sdc_method": "NOT_FOUND",
            })
            continue

        text = BeautifulSoup(
            html_file.read_text(errors="ignore"),
            "html.parser"
        ).get_text(" ")

        text = " ".join(text.split())

        sdc_matches = list(re.finditer(
            r"Susceptibility\s+distortion\s+correction:\s*(.+?)(?:\s+Coregistration|\s+Denoising|\s+HMC|\s+DWI|\s+Confounds|\s+Impute|$)",
            text,
            flags=re.IGNORECASE,
        ))

        if not sdc_matches:
            rows.append({
                "participant_id": sub,
                "session_id": "",
                "qsiprep_sdc_method": "NOT_FOUND",
            })
            continue

        for sdc_match in sdc_matches:
            method = sdc_match.group(1).strip().replace('"', "")

            # find closest previous session
            prev_text = text[:sdc_match.start()]
            session_matches = list(re.finditer(
                r"Reports\s+for\s+Session:\s*([A-Za-z0-9]+)",
                prev_text,
                flags=re.IGNORECASE,
            ))

            session_id = ""
            if session_matches:
                session_id = f"ses-{session_matches[-1].group(1)}"

            key = (sub, session_id, method)
            if key in seen:
                continue

            seen.add(key)

            rows.append({
                "participant_id": sub,
                "session_id": session_id,
                "qsiprep_sdc_method": method,
            })

    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--qsiprep-root", required=True)
    parser.add_argument("--output-tsv", required=True)
    parser.add_argument("--participant-ids", nargs="+", required=True)

    args = parser.parse_args()

    rows = extract_sdc(args.qsiprep_root, args.participant_ids)

    out_path = Path(args.output_tsv)
    write_header = not out_path.exists()

    with out_path.open("a", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["participant_id", "session_id", "qsiprep_sdc_method"],
            delimiter="\t",
        )

        if write_header:
            writer.writeheader()

        writer.writerows(rows)

    print(f"Written {len(rows)} rows to {out_path}")


if __name__ == "__main__":
    main()
