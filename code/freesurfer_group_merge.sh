#!/bin/bash
export BASEDIR=$(pwd)
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export BIDS_DIR=${BASEDIR}/data/local/bids

SUBJECTS=$(sed -n -E "s/sub-(\S*).*/\1/p" ${BIDS_DIR}/participants.tsv)


singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    /bids /derived group2 \
    --participant_label ${SUBJECTS} \
    --parcellations {aparc,aparc.a2009s}\
    --skip_bids_validator \
    --license_file /li \
    --n_cpus 80


export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1/  

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
