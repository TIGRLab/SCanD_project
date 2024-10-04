## stage 6 (extract and share files):

read -p "Do you want to extract and share data? (yes/no): " run_share
if [[ "$run_share" =~ ^(yes|y)$ ]]; then
    echo "Sharing data..."
    source ./code/06_extract_to_share.sh
else
    echo "Skipping enigma_extract."
fi
