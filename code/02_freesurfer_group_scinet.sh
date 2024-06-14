#!/bin/bash
#SBATCH --job-name=freesurfer_parcellate
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

## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export FMRIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/freesurfer-7.4.1.simg


## setting up the output folders
export OUTPUT_DIR=${BASEDIR}/data/local/freesurfer_long  # use if version of fmriprep >=20.2
#export OUTPUT_DIR=${BASEDIR}/data/local/ # use if version of fmriprep <=21.0

# export LOCAL_FREESURFER_DIR=${SCRATCH}/${STUDY}/data/derived/freesurfer-6.0.1
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${LOGS_DIR} # ${LOCAL_FREESURFER_DIR}

## get the subject list from a combo of the array id, the participants.tsv and the chunk 
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`


N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

## set singularity environment variables that will point to the freesurfer license and the templateflow bits
# export SINGULARITYENV_TEMPLATEFLOW_HOME=/home/fmriprep/.cache/templateflow
# Make sure FS_LICENSE is defined in the container.
export APPTAINERENV_FS_LICENSE=/home/freesurfer/.freesurfer.txt

# # Remove IsRunning files from FreeSurfer
# for subject in $SUBJECTS: do
#     find ${LOCAL_FREESURFER_DIR}/sub-$subject/ -name "*IsRunning*" -type f -delete
# done

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


export SUBJECTS_DIR=${BASEDIR}/data/local/freesurfer_long
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
        for lh_gcs_file in "${LH_GCS_FILES[@]}"; do
          base_name=$(basename $lh_gcs_file .gcs)
          mris_ca_label -l $SUBJECTS_DIR/$SUBJECT*long*/label/lh.cortex.label \
          $SUBJECT lh $SUBJECTS_DIR/$SUBJECT*long*/surf/lh.sphere.reg \
          $lh_gcs_file \
          $SUBJECTS_DIR/$SUBJECT*long*/label/${base_name}_order.annot
        done 

        for rh_gcs_file in "${RH_GCS_FILES[@]}"; do
          base_name=$(basename $rh_gcs_file .gcs)
          mris_ca_label -l $SUBJECTS_DIR/$SUBJECT*long*/label/rh.cortex.label \
          $SUBJECT rh $SUBJECTS_DIR/$SUBJECT*long*/surf/rh.sphere.reg \
          $rh_gcs_file \
          $SUBJECTS_DIR/$SUBJECT*long*/label/${base_name}_order.annot
        done

        for N in {1,2,3,4,5,6,7,8,9,10};do 
         mri_aparc2aseg --s $SUBJECT --o $SUBJECTS_DIR/$SUBJECT*long*/label/output_${N}00Parcels.mgz --annot Schaefer2018_${N}00Parcels_7Networks_order

         # Generate anatomical stats
         mris_anatomical_stats -a $SUBJECTS_DIR/$SUBJECT*long*/label/lh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECTS_DIR/$SUBJECT*long*/stats/lh.Schaefer2018_${N}00Parcels_7Networks_order.stats $SUBJECT lh
         mris_anatomical_stats -a $SUBJECTS_DIR/$SUBJECT*long*/label/rh.Schaefer2018_${N}00Parcels_7Networks_order.annot -f $SUBJECTS_DIR/$SUBJECT*long*/stats/rh.Schaefer2018_${N}00Parcels_7Networks_order.stats $SUBJECT rh

         # Extract stats to table format
         aparcstats2table --subjects $SUBJECT --hemi lh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECTS_DIR/$SUBJECT*long*/stats/lh.Schaefer2018_${N}00Parcels_table.tsv
         aparcstats2table --subjects $SUBJECT --hemi rh --parc Schaefer2018_${N}00Parcels_7Networks_order --measure thickness --tablefile $SUBJECTS_DIR/$SUBJECT*long*/stats/rh.Schaefer2018_${N}00Parcels_table.tsv
        done
        
     done

EOF
