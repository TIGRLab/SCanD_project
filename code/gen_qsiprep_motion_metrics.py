import argparse
import csv
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(
        description="Convert qsiprep dwiqc.json to qsiprep_metrics.csv"
    )
    script_dir = Path(__file__).resolve().parent
    default_root = script_dir.parent

    parser.add_argument(
        "--project-root",
        type=Path,
        default=default_root,
        help="SCanD project root (default: parent of code/)",
    )
    parser.add_argument(
        "--qsiprep-version",
        default="0.22.0",
        help="QSIPrep version directory under data/local/derivatives/qsiprep/",
    )
    args = parser.parse_args()

    qsiprep_dir = (
        args.project_root
        / "data/local/derivatives/qsiprep"
        / args.qsiprep_version
        / "qsiprep"
    )
    json_file_path = qsiprep_dir / "dwiqc.json"
    csv_file_path = qsiprep_dir / "qsiprep_metrics.csv"

    if not json_file_path.is_file():
        raise FileNotFoundError(f"Missing QSIPrep QC JSON: {json_file_path}")

    csv_file_path.parent.mkdir(parents=True, exist_ok=True)

    with open(json_file_path, "r") as json_file:
        data = json.load(json_file)

    subjects = data.get("subjects", [])
    if not subjects:
        print("No subjects found in the JSON data.")
        return

    with open(csv_file_path, "w", newline="") as csv_file:
        writer = csv.writer(csv_file)
        headers = list(subjects[0].keys())
        writer.writerow(headers)
        for subject in subjects:
            writer.writerow([subject.get(header, "") for header in headers])

    print(f"Data has been written to {csv_file_path}")


if __name__ == "__main__":
    main()
