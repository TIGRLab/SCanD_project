#!/bin/bash

cd $SCRATCH/SCanD_project

input_dir="data/local/derivatives/MAGeTbrain/magetbrain_data/input/subjects/brains"
output_dir="data/local/derivatives/MAGeTbrain/magetbrain_data/output/fusion/majority_vote"
temp_dir="$input_dir/temp"

mkdir -p "$temp_dir"

for input_file in "$input_dir"/*.mnc; do
    base=$(basename "$input_file" .mnc)   # e.g. sub-CMH00000001_ses-01_T1w_fixed
    output_file="$output_dir/${base}_labels.mnc"

    if [ -f "$output_file" ]; then
        echo "Found output: $output_file"
        echo "Moving input file $input_file to $temp_dir"
        mv "$input_file" "$temp_dir/"
    fi
done
