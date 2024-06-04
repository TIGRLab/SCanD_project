# Set environment variables
export BASEDIR=$PROJECTS/SCanD_project_GMANJ

export BIDS_DIR=${BASEDIR}/data/local/bids
export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export OUTPUT_DIR=${BASEDIR}/data/local/freesurfer_parcellate
export LOGS_DIR=${BASEDIR}/logs
export APPTAINERENV_FS_LICENSE=/home/freesurfer/.freesurfer.txt
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SUBJECTS_DIR=${BASEDIR}/data/local/freesurfer
export GCS_FILE_DIR=${BASEDIR}/templates/freesurfer_parcellate

# Create necessary directories
mkdir -vp ${OUTPUT_DIR} ${LOGS_DIR}

singularity exec \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${ORIG_FS_LICENSE}:/li \
    -B ${SUBJECTS_DIR}:/subjects_dir \
    -B ${GCS_FILE_DIR}:/gcs_files \
    ${SING_CONTAINER} /bin/bash << "EOF"

      # Read the subjects from participants.tsv
      SUBJECTS_FILE=/bids/participants.tsv
      SUBJECTS=$(tail -n +2 $SUBJECTS_FILE | cut -f1)

      SUBJECTS_DIR=/subjects_dir

      # List all lh and rh GCS files in the directory
      LH_GCS_FILES=(/gcs_files/lh.*.gcs)
      RH_GCS_FILES=(/gcs_files/rh.*.gcs)

      # Loop over each subject
      for SUBJECT in $SUBJECTS; do
        for lh_gcs_file in "${LH_GCS_FILES[@]}"; do
          base_name=$(basename $lh_gcs_file .gcs)
          mris_ca_label -l $SUBJECTS_DIR/$SUBJECT/label/lh.cortex.label \
          $SUBJECT lh $SUBJECTS_DIR/$SUBJECT/surf/lh.sphere.reg \
          $lh_gcs_file \
          $SUBJECTS_DIR/$SUBJECT/label/${base_name}_order.annot
        done 

        for rh_gcs_file in "${RH_GCS_FILES[@]}"; do
          base_name=$(basename $rh_gcs_file .gcs)
          mris_ca_label -l $SUBJECTS_DIR/$SUBJECT/label/rh.cortex.label \
          $SUBJECT rh $SUBJECTS_DIR/$SUBJECT/surf/rh.sphere.reg \
          $rh_gcs_file \
          $SUBJECTS_DIR/$SUBJECT/label/${base_name}_order.annot
        done
        
      done

EOF
