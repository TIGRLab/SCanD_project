# Set your variables
BASEDIR=/path/to/basedir
BIDS_DIR=/path/to/bids_dir
OUTPUT_DIR=/path/to/output_dir
ORIG_FS_LICENSE=/path/to/license.txt
SING_CONTAINER=/path/to/freesurfer-7.4.1.simg
SUBJECTS_DIR=/path/to/subjects_dir
GCS_FILE_DIR=/path/to/gcs_files
SUBJECT=subject01

# Run Singularity with the appropriate bindings and environment setup
singularity run --cleanenv \
  -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
  -B ${BIDS_DIR}:/bids \
  -B ${OUTPUT_DIR}:/derived \
  -B ${ORIG_FS_LICENSE}:/li \
  -B ${SUBJECTS_DIR}:/subjects \
  -B ${GCS_FILE_DIR}:/gcs_files \
  ${SING_CONTAINER} \
  /bin/bash -c "
    export SUBJECTS_DIR=/subjects

    mris_ca_label -l \$SUBJECTS_DIR/${SUBJECT}/label/lh.cortex.label \
      ${SUBJECT} lh \$SUBJECTS_DIR/${SUBJECT}/surf/lh.sphere.reg \
      /gcs_files/lh.Schaefer2018_400Parcels_17Networks.gcs \
      \$SUBJECTS_DIR/${SUBJECT}/label/lh.Schaefer2018_400Parcels_17Networks_order.annot

    mris_ca_label -l \$SUBJECTS_DIR/${SUBJECT}/label/rh.cortex.label \
      ${SUBJECT} rh \$SUBJECTS_DIR/${SUBJECT}/surf/rh.sphere.reg \
      /gcs_files/rh.Schaefer2018_400Parcels_17Networks.gcs \
      \$SUBJECTS_DIR/${SUBJECT}/label/rh.Schaefer2018_400Parcels_17Networks_order.annot
  "
