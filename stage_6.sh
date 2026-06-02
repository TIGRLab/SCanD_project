#!/bin/bash

## stage 6 (extract and share files):

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR" || exit 1

read -p "Do you want to extract and share data? (yes/no): " run_share
if [[ "$run_share" =~ ^(yes|y)$ ]]; then
    echo "Sharing data..."
    sbatch ./code/06_extract_to_share_slurm.sh
    source ./code/06_extract_to_share_terminal.sh
else
    echo "Skipping extract and share."
fi
