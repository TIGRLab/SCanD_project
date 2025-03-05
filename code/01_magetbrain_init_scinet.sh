#!/bin/bash
#SBATCH --job-name=magetbrain_init
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=1000

module load apptainer/1.3.5

PROJECT_DIR=${SLURM_SUBMIT_DIR}

# Copy container
SING_CONTAINER="$PROJECT_DIR/containers/magetbrain.sif"

# Define directories
BIDS_DIR="$PROJECT_DIR/data/local/bids"
MAGETBRAIN_DIR="$PROJECT_DIR/data/local/MAGeTbrain/magetbrain_data"
INPUT_DIR="$MAGETBRAIN_DIR/input"

# Create necessary directories
mkdir -p "$INPUT_DIR/subjects/brains"
mkdir -p "$INPUT_DIR/templates/brains"

# Define the path to the demographic TSV file
DEMOGRAPHIC_FILE="$PROJECT_DIR/data/local/bids/participants_demographic.tsv"

# Function to select subjects randomly based on age and gender
select_random_subjects() {
    local num_subjects=$1
    shift
    local subjects=("$@")

    # Sort subjects by age (second column) using a temporary file for sorting
    sorted_subjects=($(for subject in "${subjects[@]}"; do
        # Extract the subject ID and age from the demographic file
        age=$(grep -P "^$subject\t" "$DEMOGRAPHIC_FILE" | cut -f2)
        echo "$subject,$age"
    done | sort -t, -k2,2n))

    # Select the specified number of subjects randomly
    selected_subjects=()
    while [[ ${#selected_subjects[@]} -lt $num_subjects ]]; do
        random_index=$((RANDOM % ${#sorted_subjects[@]}))
        subject=$(echo "${sorted_subjects[$random_index]}" | cut -d, -f1)

        # Avoid duplicates
        if [[ ! " ${selected_subjects[@]} " =~ " ${subject} " ]]; then
            selected_subjects+=("$subject")
        fi
    done
    echo "${selected_subjects[@]}"
}

# Check if the demographic file exists
if [[ -f "$DEMOGRAPHIC_FILE" ]]; then
    # Separate males and females based on the third column (Gender)
    male_subjects=($(awk -F'\t' '$3 == "Male" {print $1}' "$DEMOGRAPHIC_FILE"))
    female_subjects=($(awk -F'\t' '$3 == "Female" {print $1}' "$DEMOGRAPHIC_FILE"))

    # Select 11 males and 10 females randomly based on age for templates
    selected_males_for_templates=($(select_random_subjects 11 "${male_subjects[@]}"))
    selected_females_for_templates=($(select_random_subjects 10 "${female_subjects[@]}"))

    # Combine males and females into one array
    selected_subjects=("${selected_males_for_templates[@]}" "${selected_females_for_templates[@]}")
    
else
    selected_subjects=($(tail -n +2 "$BIDS_DIR/participants.tsv" | cut -f1 | shuf -n 21))
fi

# Process each subject in BIDS
subjects=$(tail -n +2 "$BIDS_DIR/participants.tsv" | cut -f1)

for subject in $subjects; do
    echo "Processing subject: $subject"

    # Check for session directories
    session_dirs=("$BIDS_DIR/$subject/ses-"*)
    if [[ -d "${session_dirs[0]}" ]]; then
        # If session directories exist, process them
        for session in "${session_dirs[@]}"; do
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
                    singularity run -B ${INPUT_DIR}:/input ${SING_CONTAINER} \
                        nii2mnc "/input/subjects/brains/${subject}_${ses_name}_T1w.nii" \
                                "/input/subjects/brains/${subject}_${ses_name}_T1w.mnc"
                else
                    echo "  No T1w file found for session $ses_name"
                fi
            fi
        done
    else

        # If no session directories exist, process anatomical data directly
        echo "  No sessions found for subject $subject, processing anatomical data"

        anat_dir="$BIDS_DIR/$subject/anat"
        if [[ -d "$anat_dir" ]]; then
            t1w_file=$(find "$anat_dir" -name "*T1w.nii.gz" | head -n 1)
            if [[ -n "$t1w_file" ]]; then
                new_t1w_name="$INPUT_DIR/subjects/brains/${subject}_T1w.nii.gz"
                cp "$t1w_file" "$new_t1w_name"
                gunzip -f "$new_t1w_name"

                # Convert to MINC
                singularity run -B ${INPUT_DIR}:/input ${SING_CONTAINER} \
                    nii2mnc "/input/subjects/brains/${subject}_T1w.nii" \
                            "/input/subjects/brains/${subject}_T1w.mnc"
            else
                echo "  No T1w file found for subject $subject"
            fi
        else
            echo "  No anatomical data found for subject $subject"
        fi
    fi
done


# Process template subjects (selected randomly)


# Copy atlas data
cp -r /scratch/arisvoin/shared/templateflow/atlases  "$INPUT_DIR/"
