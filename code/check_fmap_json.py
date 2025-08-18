import argparse
import json
import os
from pathlib import Path

from bids import BIDSLayout, BIDSLayoutIndexer
from rich import print
from rich.console import Console
from rich.panel import Panel
from rich.table import Table


def get_log_file(log_filename="dwi_qc_summary.log"):
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
        title="📋 Diffusion Fieldmap QC Summary",
        title_style="bold magenta",
        show_header=True,
        header_style="bold cyan",
        row_styles=["none", "dim"],
    )
    table.add_column("Subject", style="bold white")
    table.add_column("Session", style="white")
    table.add_column("Fieldmap", style="green")
    table.add_column("IntendedFor", style="yellow")

    # Filter failed results
    failed_results = [r for r in results if "❌" in r[2] or "❌" in r[3]]

    # Use failed_results for the table if you only want to display failures
    table_results = failed_results if failed_results else results

    for row in table_results:
        table.add_row(*row)

    console.print(table)
    file_console.print(table)

    total = len(results)
    failed = sum(1 for r in results if "❌" in r[2] or "❌" in r[3])
    passed = total - failed

    summary = [
        "",
        f"[bold green]✅ Passed:[/] {passed}",
        f"[bold red]❌ Failed:[/] {failed}",
        f"[bold]Total:[/] {total}",
    ]
    if failed:
        console.print(
            "[bold yellow]⚠️ Please review failed subjects above.[/bold yellow]"
        )

    for line in summary:
        console.print(line)
        file_console.print(line)

    # if messages:
    #     warning_panel = Panel(
    #         "\n".join(messages),
    #         title="[bold yellow]QC Warnings[/bold yellow]",
    #         border_style="white",
    #         padding=(1, 2),
    #     )
    #     console.print(warning_panel)
    #     file_console.print(warning_panel)


def check_fmap_intendedfor(subject_layout, subject, session):
    messages = []
    results = []

    session_kwargs = {"session": session} if session else {}
    session_label = f"ses-{session}" if session else "no-session"

    fmap_jsons = subject_layout.get(
        subject=subject,
        datatype="fmap",      # restrict to fmap folder
        acquisition="dwi",  # grabbing all json maps not clean  
        extension=".json",    
        return_type="file",
        **session_kwargs
    )

    dwi_images = subject_layout.get(
        subject=subject,
        datatype="dwi",
        suffix="dwi",
        extension=".nii.gz",
        return_type="file",
        **session_kwargs,
    )

    # fmri_images = subject_layout.get(
    #     subject=subject,
    #     suffix="bold",
    #     extension=".nii.gz",
    #     return_type="file",
    #     **session_kwargs,
    # )

    fmap_valid = bool(fmap_jsons)
    intended_valid = False

    if len(dwi_images) != 1:
        messages.append(
            f"[{subject}, {session_label}] Expected one DWI image, found {len(dwi_images)}."
        )

    if not fmap_jsons:
        messages.append(f"[{subject}, {session_label}] No fieldmap JSONs found.")
    else:
        for fmap_path in fmap_jsons:
            with open(fmap_path) as f:
                metadata = json.load(f)

            intended_for = metadata.get("IntendedFor", [])
            
            # Ensure list type
            if isinstance(intended_for, str):
                intended_for = [intended_for]

            # Remove blank strings
            intended_for = [entry for entry in intended_for if entry.strip()]

            if not intended_for:
                messages.append(
                    f"[{subject}, {session_label}] Fieldmap {os.path.basename(fmap_path)} missing IntendedFor."
                )
                continue

            # Check if all IntendedFor entry matches an actual DWI image
            matched = all(
                any(dwi_path.endswith(intended) for dwi_path in dwi_images)
                for intended in intended_for
            )

            # Check if all IntendedFor entry matches an actual fMRI image
            # matched = all(
            #     any(fmri_path.endswith(intended) for fmri_path in fmri_images)
            #     for intended in intended_for
            # )
                    
            if matched:
                intended_valid = True
            else:
                messages.append(
                    f"[{subject}, {session_label}] IntendedFor in {os.path.basename(fmap_path)} does not match any DWI file."
                )

    fmap_status = "✅ Found" if fmap_valid else "❌ Missing"
    intended_status = "✅ Valid" if intended_valid else "❌ Invalid/Missing"
    results.append((subject, session_label, fmap_status, intended_status))
    return results, messages
    
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
            subject_results, subject_messages = check_fmap_intendedfor(
                subject_layout, subject, session
            )
            results.extend(subject_results)
            all_messages.extend(subject_messages)

    summarize_results(results, all_messages, get_log_file())


def parse_args():
    parser = argparse.ArgumentParser(
        description="Check if fieldmaps match DWI files via IntendedFor."
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
                    participants.extend(line.strip().removeprefix("sub-") for line in f)
            else:
                participants.append(item.removeprefix("sub-"))
    else:
        participants = None
    run_qc(args.bids_dir, subjects=participants)

