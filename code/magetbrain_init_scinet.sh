#!/bin/bash
#SBATCH --job-name=magetbrain_init
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=1000

# Load necessary module for nii2mnc
module load minc-toolkit/1.9.18.3  

# Define directories
SCRATCH="/scratch/ghazalm"
PROJECT_DIR="$SCRATCH/SCanD_project/data/local"
BIDS_DIR="$PROJECT_DIR/bids"
FMRIPREP_DIR="$PROJECT_DIR/derivatives/fmriprep/23.2.3"
MAGETBRAIN_DIR="$PROJECT_DIR/MAGeTbrain/magetbrain_data"
INPUT_DIR="$MAGETBRAIN_DIR/input"

# Create necessary directories if they don't exist
mkdir -p "$INPUT_DIR/subjects/brains"
mkdir -p "$INPUT_DIR/templates/brains"


# Read subjects from participants.tsv (excluding header)
subjects=$(tail -n +2 "$BIDS_DIR/participants.tsv" | cut -f1)

# Process each subject
for subject in $subjects; do
    echo "Processing subject: $subject"

    # Process each session for the subject
    for session in "$BIDS_DIR/$subject"/ses-*; do
        if [[ -d "$session" ]]; then
            ses_name=$(basename "$session")
            echo "  Processing session: $ses_name"

            # Copy anatomical data (T1w)
            t1w_file=$(find "$session/anat" -name "*T1w.nii.gz" | head -n 1)
            if [[ -n "$t1w_file" ]]; then
                new_t1w_name="$INPUT_DIR/subjects/brains/${subject}_${ses_name}_T1w.nii.gz"
                cp "$t1w_file" "$new_t1w_name"
                gunzip -f "$new_t1w_name"

                # Convert to MINC
                nii2mnc "${new_t1w_name%.gz}" "${new_t1w_name%.nii.gz}.mnc"
            else
                echo "  No T1w file found for session $ses_name"
            fi

            # Find and copy the first functional file for this session
            first_func_file=$(find "$FMRIPREP_DIR/$subject/$ses_name/func" -name "*space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz" | sort | head -n 1)
            if [[ -n "$first_func_file" ]]; then
                new_func_name="$INPUT_DIR/templates/brains/${subject}_${ses_name}_bold.nii.gz"
                cp "$first_func_file" "$new_func_name"
                gunzip -f "$new_func_name"

                # Convert to MINC
                nii2mnc "${new_func_name%.gz}" "${new_func_name%.nii.gz}.mnc"
            else
                echo "  No MNI functional file found for session $ses_name"
            fi
        fi
    done
done

# Copy atlas data
cp -r /scratch/arisvoin/shared/temp/atlases "$INPUT_DIR/"

echo "Processing complete!"
