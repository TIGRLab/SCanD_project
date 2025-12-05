import argparse
import json
import os
from pathlib import Path

from bids import BIDSLayout, BIDSLayoutIndexer
from rich import print
from rich.console import Console
from rich.panel import Panel
from rich.table import Table


def get_log_file(log_filename="fieldmap_qc_summary.log"):
    script_dir = Path(__file__).resolve().parent
    logs_dir = script_dir.parent / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    return logs_dir / log_filename

def summarize_results(results, messages, log_path):
    console = Console()
    file_console = Console(
        file=open(log_path, "w"), force_terminal=True, color_system="truecolor"
    )

    table = Table(
        title="📋 Fieldmap QC Summary",
        title_style="bold magenta",
        show_header=True,
        header_style="bold cyan",
        row_styles=["none", "dim"],
    )
    table.add_column("FileName", style="bold white")
    table.add_column("DataType", style="white")
    # table.add_column("Fieldmap", style="green")
    table.add_column("IntendedFor", style="yellow")

    # Filter failed results
    # failed_results = [r for r in results if "❌" in r[2] or "❌" in r[3]]
    failed_results = [r for r in results if "❌" in r[2]]
    # Use failed_results for the table if you only want to display failures
    table_results = failed_results if failed_results else results

    for row in table_results:
        filename, datatype, intended_status = row

        # Color the IntendedFor cell based on status
        if "❌" in intended_status:
            intended_status = f"[red]{intended_status}[/red]"
        elif "✅" in intended_status:
            intended_status = f"[green]{intended_status}[/green]"

        table.add_row(filename, datatype, intended_status)
        # table.add_row(*row)  # row: (filename, datatype, intended_status)

    console.print(table)
    file_console.print(table)

    total = len(results)
    failed = sum(1 for r in results if "❌" in r[2])
    passed = total - failed

    summary = [
        "",
        f"[bold green]✅ Passed:[/] {passed}",
        f"[bold red]❌ Failed:[/] {failed}",
        f"[bold]Total:[/] {total}",
    ]
    if failed:
        console.print(
            "[bold yellow]⚠️ Please review failed images above.[/bold yellow]"
        )

    for line in summary:
        console.print(line)
        file_console.print(line)

def check_fmap_intendedfor(subject_layout, subject, session):
    
    messages = []
    results = []
    session_kwargs = {"session": session} if session else {}
    session_label = f"ses-{session}" if session else "no-session"
    
    target_imgs = subject_layout.get(
        subject=subject,
        datatype=["func","dwi"],
        extension="nii.gz",
        **session_kwargs
    )
    if not target_imgs:
        print(f"WARNING: No functional or DWI data found for subject {subject}")
    # Scans the JSON sidecars of all files in the fmap/ 
    # It looks specifically for the IntendedFor field
    # If it finds a match: It returns a list containing the paths to the fieldmap NIfTI files
    # If you have a fieldmap file, but the JSON is missing the IntendedFor line: This function returns [] (Empty).
    # If you have a fieldmap file, but the filename in IntendedFor has a typo: This function returns [] (Empty).
    # For example: 
        # [
        #  {'epi': '/projects/ttan/EPIPHANI/data/local/bids/sub-CMH0014/ses-02/fmap/sub-CMH0014_ses-02_acq-rest_dir-AP_run-01_epi.nii.gz', 'suffix': 'epi'},
        #  {'epi': '/projects/ttan/EPIPHANI/data/local/bids/sub-CMH0014/ses-02/fmap/sub-CMH0014_ses-02_acq-rest_dir-PA_run-01_epi.nii.gz', 'suffix': 'epi'}
        # ]
    for img in target_imgs:
        fieldmaps = subject_layout.get_fieldmap(img.path, return_list=True)
        datatype = img.entities.get("datatype", "unknown")

        has_fmap = bool(fieldmaps)  # True if ANY fieldmap matches this exact file

        if not has_fmap:
            messages.append(f"Missing or wrong IntendedFor: {img.filename}")

        intended_status = "✅ Valid" if has_fmap else "❌ Invalid/Missing"

        results.append((img.filename, datatype, intended_status))
    return messages, results

def run_qc(bids_dir, subjects=None, layout=None):
    results, all_messages = [], []
    if layout:
        subject_layout = layout
    elif subjects and len(subjects) < 50:
        ignore_regex = f"(?!sub-({'|'.join(subjects)})).*"
        indexer = BIDSLayoutIndexer(ignore=[ignore_regex])
        subject_layout = BIDSLayout(bids_dir, validate=False, indexer=indexer)
    else:
        subject_layout = BIDSLayout(bids_dir, validate=False)

    subjects = subjects or subject_layout.get_subjects()

    for subject in subjects:
        sessions = subject_layout.get_sessions(subject=subject) or [None]
        for session in sessions:
            subject_messages, subject_results = check_fmap_intendedfor(
                subject_layout, subject, session
            )
            results.extend(subject_results)
            all_messages.extend(subject_messages)       
    summarize_results(results, all_messages, get_log_file())

def parse_args():
    parser = argparse.ArgumentParser(
        description="Check if fieldmap json match inteded functional files via IntendedFor."
    )

    default_bids_dir = (
        Path(__file__).resolve().parent.parent / "data" / "local" / "bids"
    )

    # Positional argument for BIDS directory
    parser.add_argument(
        "bids_dir",
        nargs="?",
        default=str(default_bids_dir),
        help="BIDS dataset root"
    )

    # Positional argument for participant labels (can accept multiple)
    parser.add_argument(
        "participant_label",
        nargs="+",
        help="Space-separated list of subject IDs or path to a file"
    )

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    if args.participant_label:
        participants = []
        for item in args.participant_label:
            if os.path.isfile(item):
                with open(item) as f:
                    for line in f:
                        line = line.strip()
                        # Skip blank lines and the header
                        if not line or line.lower() == "participant_id":
                            continue
                        participants.append(line.removeprefix("sub-"))
            else:
                participants.append(item.removeprefix("sub-"))
    else:
        participants = None

    run_qc(args.bids_dir, subjects=participants)
