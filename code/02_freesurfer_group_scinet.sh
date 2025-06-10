#!/bin/bash
#SBATCH --job-name=freesurfer_group
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=06:00:00
#SBATCH --mem-per-cpu=8000

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

module load apptainer/1.3.5
export BIDS_DIR=${BASEDIR}/data/local/bids
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg 
export LOGS_DIR=${BASEDIR}/logs
export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt
#export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/sourcedata/freesurfer/
export SUBJECTS_DIR=${BASEDIR}/data/local/derivatives/freesurfer/7.4.1
export GCS_FILE_DIR=${BASEDIR}/templates/freesurfer_parcellate

SUB_SIZE=1

bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS_BATCH=$(sed -n -E "s/(sub-\S*)/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${N_SUBJECTS} | tail -n ${Tail})
else
    SUBJECTS_BATCH=$(sed -n -E "s/(sub-\S*)/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE})
fi


singularity exec \
    -B ${BASEDIR}/templates:/home/freesurfer --home /home/freesurfer \
    -B ${BIDS_DIR}:/bids \
    -B ${ORIG_FS_LICENSE}:/opt/freesurfer/.license  \
    -B ${SUBJECTS_DIR}:/subjects_dir \
    -B ${GCS_FILE_DIR}:/gcs_files \
    --env SUBJECT_BATCH="$SUBJECTS_BATCH" \
    ${SING_CONTAINER} /bin/bash << "EOF"

    export SUBJECTS_DIR=/subjects_dir

    # List all lh and rh GCS files in the directory
    LH_GCS_FILES=(/gcs_files/lh.*.gcs)
    RH_GCS_FILES=(/gcs_files/rh.*.gcs)

    # Loop over each subject
    for SUBJECT in $SUBJECT_BATCH; do

      SUBJECT_LONG_DIRS=$(find $SUBJECTS_DIR -maxdepth 1 -name "${SUBJECT}*.long.${SUBJECT}" -type d)

      subject_exitcode=0  # Initialize success for each subject

      # Check if SUBJECT_LONG_DIRS is empty
      if [ -z "$SUBJECT_LONG_DIRS" ]; then
        echo "$SUBJECT   ${SLURM_ARRAY_TASK_ID}    No longitudinal directories found" >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
        subject_exitcode=1
        continue  # Skip the rest of the loop for this subject
      fi

      for SUBJECT_LONG_DIR in $SUBJECT_LONG_DIRS; do
        sub=$(basename $SUBJECT_LONG_DIR)

        for lh_gcs_file in "${LH_GCS_FILES[@]}"; do
          base_name=$(basename $lh_gcs_file .gcs)
          mris_ca_label -l $SUBJECT_LONG_DIR/label/lh.cortex.label \
          $sub lh $SUBJECT_LONG_DIR/surf/lh.sphere.reg \
          $lh_gcs_file \
          $SUBJECT_LONG_DIR/label/${base_name}_order.annot

          # Check if the command was successful
          if [ $? -ne 0 ]; then
            subject_exitcode=1
            break
          fi
        done

        for rh_gcs_file in "${RH_GCS_FILES[@]}"; do
          base_name=$(basename $rh_gcs_file .gcs)
          mris_ca_label -l $SUBJECT_LONG_DIR/label/rh.cortex.label \
          $sub rh $SUBJECT_LONG_DIR/surf/rh.sphere.reg \
          $rh_gcs_file \
          $SUBJECT_LONG_DIR/label/${base_name}_order.annot

          # Check if the command was successful
          if [ $? -ne 0 ]; then
            subject_exitcode=1
            break
          fi
        done

        # Continue processing even if the commands above failed
        for N in {1,2,3,4,5,6,7,8,9,10}; do
          mri_aparc2aseg --s $sub --o $SUBJECT_LONG_DIR/label/output_${N}00Parcels.mgz --annot Schaefer2018_${N}00Parcels_7Networks_order || subject_exitcode=1

          # Generate anatomical stats
          mris_anatomical_stats -a $SUBJECT_LONG_DIR/label/lh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_7Networks_order.stats $sub lh || subject_exitcode=1
          mris_anatomical_stats -a $SUBJECT_LONG_DIR/label/rh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_7Networks_order.stats $sub rh || subject_exitcode=1

          # Extract stats-thickness to table format
          aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_thickness.tsv || subject_exitcode=1
          aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_thickness.tsv || subject_exitcode=1

          # Extract stats-gray matter volume to table format
          aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure volume --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_grayvol.tsv || subject_exitcode=1
          aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure volume --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_grayvol.tsv || subject_exitcode=1

          # Extract stats-surface area to table format
          aparcstats2table --subjects $sub --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure area --tablefile $SUBJECT_LONG_DIR/stats/lh.Schaefer2018_${N}00Parcels_table_surfacearea.tsv || subject_exitcode=1
          aparcstats2table --subjects $sub --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure area --tablefile $SUBJECT_LONG_DIR/stats/rh.Schaefer2018_${N}00Parcels_table_surfacearea.tsv || subject_exitcode=1

        done

      done

      # Now log success or failure per subject
      if [ $subject_exitcode -eq 0 ]; then
          echo "$SUBJECT   ${SLURM_ARRAY_TASK_ID}    0" >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
      else
          echo "$SUBJECT   ${SLURM_ARRAY_TASK_ID}    freesurfer_group failed" >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
      fi

    done

EOF


## nipoppy trackers 

singularity exec \
  --bind ${SCRATCH}:${SCRATCH} \
  --env SUBJECTS_BATCH="$SUBJECTS_BATCH" \
  containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    BASEDIR="$SCRATCH/SCanD_project"
    cd "$BASEDIR/Neurobagel"
    
    mkdir -p derivatives/freesurfergroup/7.4.1/output/
    ls -al derivatives/freesurfergroup/7.4.1/output/

    ln -s "$BASEDIR/data/local/derivatives/freesurfer/7.4.1/"* derivatives/freesurfergroup/7.4.1/output/ || true

    for subject in $SUBJECTS_BATCH; do
      nipoppy track \
        --pipeline freesurfergroup \
        --pipeline-version 7.4.1 \
        --participant-id $subject
    done
  '
