#!/bin/bash
#SBATCH --job-name=freesurfer_parcellate
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=3:00:00



####----### the next bit only works IF this script is submitted from the $BASEDIR/$OPENNEURO_DS folder...

## set the second environment variable to get the base directory
BASEDIR=${SLURM_SUBMIT_DIR}

## set up a trap that will clear the ramdisk if it is not cleared
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

#trap the termination signal, and call the function 'trap_term' when
# that happens, so results may be saved.
trap "cleanup_ramdisk" TERM

SUBJECTS=$(cut -f 1 ${BASEDIR}/data/local/bids/participants.tsv | tail -n +2)

# Iterate over each subject in SUBJECTS
for subject in $SUBJECTS; do
    echo "$subject       0" >> ${BASEDIR}/logs/freesurfer_parcellate.tsv
done


export BIDS_DIR=${BASEDIR}/data/local/bids
export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export LOGS_DIR=${BASEDIR}/logs
export APPTAINERENV_FS_LICENSE=/home/freesurfer/.freesurfer.txt
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
export SUBJECTS_DIR=${BASEDIR}/data/local/freesurfer_long
export GCS_FILE_DIR=${BASEDIR}/templates/freesurfer_parcellate

# Create necessary directories
mkdir -vp ${OUTPUT_DIR} ${LOGS_DIR}

singularity exec \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
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

        for N in {1,2,3,4,5,6,7,8,9,10};do 
         mri_aparc2aseg --s $SUBJECT --o output.mgz --annot Schaefer2018_${N}00Parcels_7Networks_order
        done
        
      done

EOF
