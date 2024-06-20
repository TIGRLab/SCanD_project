#!/bin/bash
#SBATCH --job-name=freesurfer_group
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=3:00:00

SUB_SIZE=1 ## number of subjects to run

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

# input is BIDS_DIR this is where the data downloaded from openneuro went
export BIDS_DIR=${BASEDIR}/data/local/bids
export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1  # use if version of fmriprep >=20.2
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${LOGS_DIR} # ${LOCAL_FREESURFER_DIR}

SUBJECTS=$(sed -n -E "s/sub-(\S*).*/\1/p" ${BIDS_DIR}/participants.tsv)

    
export APPTAINERENV_FS_LICENSE=/home/freesurfer/.freesurfer.txt
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

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



SUBJECTS=$(cut -f 1 ${BASEDIR}/data/local/bids/participants.tsv | tail -n +2)

# Iterate over each subject in SUBJECTS
for subject in $SUBJECTS; do
    echo "$subject       0" >> ${BASEDIR}/logs/freesurfer_group.tsv
done


export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
export GCS_FILE_DIR=${BASEDIR}/templates/freesurfer_parcellate


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
      
        SUBJECT_LONG_DIRS=$(find $SUBJECTS_DIR -maxdepth 1 -name "${SUBJECT}*.long.${SUBJECT}" -type d)
        
        for SUBJECT_LONG_DIR in $SUBJECT_LONG_DIRS; do
          sub=$(basename $SUBJECT_LONG_DIR)
    
          for lh_gcs_file in "${LH_GCS_FILES[@]}"; do
            base_name=$(basename $lh_gcs_file .gcs)
            mris_ca_label -l $SUBJECT_LONG_DIR/label/lh.cortex.label \
            $sub lh $SUBJECT_LONG_DIR/surf/lh.sphere.reg \
            $lh_gcs_file \
            $SUBJECT_LONG_DIR/label/${base_name}_order.annot
          done 

          for rh_gcs_file in "${RH_GCS_FILES[@]}"; do
            base_name=$(basename $rh_gcs_file .gcs)
            mris_ca_label -l $SUBJECT_LONG_DIR/label/rh.cortex.label \
            $sub rh $SUBJECT_LONG_DIR/surf/rh.sphere.reg \
            $rh_gcs_file \
            $SUBJECT_LONG_DIR/label/${base_name}_order.annot
          done
          
          for N in {1,2,3,4,5,6,7,8,9,10};do 
            mri_aparc2aseg --s $sub --o $SUBJECT_LONG_DIR/label/output_${N}00Parcels.mgz --annot Schaefer2018_${N}00Parcels_7Networks_order

            # Generate anatomical stats
            mris_anatomical_stats -a $SUBJECT_LONG_DIR/label/lh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_7Networks_order.stats $sub lh
            mris_anatomical_stats -a $SUBJECT_LONG_DIR/label/rh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_7Networks_order.stats $sub rh

            # Extract stats-thickness to table format
            aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_thickness.tsv
            aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_thickness.tsv

            # Extract stats-gray matter volume to table format
            aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure volume --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_grayvol.tsv
            aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure volume --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_grayvol.tsv

            # Extract stats-surface area to table format
            aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure area --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_surfacearea.tsv
            aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure area --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_surfacearea.tsv

          done
        
        done
     
      done   

EOF


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

