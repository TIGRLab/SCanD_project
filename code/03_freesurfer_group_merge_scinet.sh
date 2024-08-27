export BIDS_DIR=$SCRATCH/SCanD_project/data/local/bids

SUBJECTS=$(sed -n -E "s/sub-(\S*).*/\1/p" ${BIDS_DIR}/participants.tsv)

export SUBJECTS_DIR=${BASEDIR}/data/local/freesurfer_long

# Merging TSV files
OUTPUT_MERGE_DIR=${SUBJECTS_DIR}/00_group2_stats_tables
mkdir -p ${OUTPUT_MERGE_DIR}

SUBJECTS_FILE=${BIDS_DIR}/participants.tsv
SUBJECTS=$(tail -n +2 $SUBJECTS_FILE | cut -f1)

#!/bin/bash

types=("thickness" "grayvol" "surfacearea")

for N in {1..10}; do
  for hemi in lh rh; do
    for type in "${types[@]}"; do
      OUTPUT_FILE=${OUTPUT_MERGE_DIR}/${hemi}.Schaefer2018_${N}00Parcels.${type}.tsv
      HEADER_ADDED=false

      for subject in $SUBJECTS; do
        SUBJECT_LONG_DIRS=$(find $SUBJECTS_DIR -maxdepth 1 -name "${subject}*.long.${subject}" -type d)

        for SUBJECT_LONG_DIR in $SUBJECT_LONG_DIRS; do
          FILE=${SUBJECT_LONG_DIR}/stats/${hemi}.Schaefer2018_${N}00Parcels_table_${type}.tsv

          if [ -f "$FILE" ]; then
            if [ "$HEADER_ADDED" = false ]; then
              head -n 1 $FILE > $OUTPUT_FILE
              HEADER_ADDED=true
            fi

            tail -n +2 $FILE >> $OUTPUT_FILE
          else
            echo "File $FILE not found, skipping..."
          fi
        done
      done
    done
  done
done