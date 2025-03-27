## stage 7 (extract and share files):

read -p "Do you want to extract and share data? (yes/no): " run_share
if [[ "$run_share" =~ ^(yes|y)$ ]]; then
    echo "Sharing data..."
    sbatch ./code/07_extract_to_share_slurm.sh
    source ./code/07_extract_to_share_terminal.sh
else
    echo "Skipping enigma_extract."
fi
