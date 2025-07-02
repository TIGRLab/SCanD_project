## stage 6 (extract and share files):

read -p "Do you want to extract and share data? (yes/no): " run_share
if [[ "$run_share" =~ ^(yes|y)$ ]]; then
    echo "Sharing data..."
    sbatch ./code/06_extract_to_share_slurm.sh
    source ./code/06_extract_to_share_terminal.sh
else
    echo "Skipping enigma_extract."
fi
