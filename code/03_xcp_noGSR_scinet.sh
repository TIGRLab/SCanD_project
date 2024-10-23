#!/bin/bash
#SBATCH --job-name=xcp_noGSR
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=80
#SBATCH --time=05:00:00


SUB_SIZE=1 ## number of subjects to run is 1 because there are multiple tasks/run that will run in parallel
CORES=40
export THREADS_PER_COMMAND=2

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

export BIDS_DIR=${BASEDIR}/data/local/bids
export SING_CONTAINER=${BASEDIR}/containers/xcp_d-0.7.3.simg


## setting up the output folders
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/xcp_noGSR
export FMRI_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/
export CONFOUND_DIR=${BASEDIR}/data/local/derivatives/fmriprep/23.2.3/custom_confounds/

project_id=$(cat ${BASEDIR}/project_id)
export WORK_DIR=${BBUFFER}/SCanD/${project_id}/xcp_noGSR
export LOGS_DIR=${BASEDIR}/logs
export FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} ${CONFOUND_DIR}


SUBJECTS=$(awk -F'\t' 'NR>1 {print $1}' ${BIDS_DIR}/participants.tsv)
for subject in $SUBJECTS; do
  # Find the confounds_timeseries.tsv files for the current subject
  FILES=$(find $FMRI_DIR -type f -path "*/${subject}/*confounds_timeseries.tsv*")
  for file in $FILES; do
    output_file="${CONFOUND_DIR}/$(basename ${file})"
    # Extract the header
    header=$(head -n 1 $file)
    # Determine the columns to keep
    cols_to_keep=$(echo "$header" | awk -F'\t' '
      {
        for (i=1; i<=NF; i++) {
          if ($i ~ /^rot/ || $i ~ /^trans/ || $i ~ /^csf/ || $i ~ /^white_matter/) {
            if ($i != "csf_wm") {
              if (cols != "") cols = cols "\t";
              cols = cols $i;
            }
          }
        }
      }
      END { print cols }
    ')
    # Filter the file to keep only the selected columns
    awk -F'\t' -v OFS='\t' -v cols="$cols_to_keep" '
      BEGIN {
        split(cols, col_arr, OFS);
        for (i in col_arr) {
          col_idx[col_arr[i]] = 1;
        }
      }
      NR == 1 {
        for (i = 1; i <= NF; i++) {
          if ($i in col_idx) {
            header_idx[i] = $i;
          }
        }
        out = "";
        for (i = 1; i <= NF; i++) {
          if (header_idx[i]) {
            if (out != "") out = out OFS;
            out = out header_idx[i];
          }
        }
        print out;
      }
      NR > 1 {
        out = "";
        for (i = 1; i <= NF; i++) {
          if (header_idx[i]) {
            if (out != "") out = out OFS;
            out = out $i;
          }
        }
        print out;
      }
    ' $file > $output_file
  done
done


## get the subject list from a combo of the array id, the participants.tsv and the chunk size
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi



singularity run --cleanenv \
-B ${BASEDIR}/templates:/home/fmriprep --home /home/fmriprep \
-B ${OUTPUT_DIR}:/out \
-B ${FMRI_DIR}:/fmriprep \
-B ${WORK_DIR}:/work \
-B ${CONFOUND_DIR}:/confounds \
-B ${FS_LICENSE}:/li \
${SING_CONTAINER} \
    /fmriprep \
    /out \
    participant \
    --participant_label ${SUBJECTS} \
    -w /work \
    --cifti \
    --smoothing 0 \
    --fd-thresh 0 \
    --dummy-scans 3 \
    --nuisance-regressors custom \
    --custom_confounds /confounds \
    --fs-license-file /li \
    --notrack

# note, if you have top-up fieldmaps than you can uncomment the last two lines of the above script

exitcode=$?

# Output results to a table
for subject in $SUBJECTS; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    xcp_d failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done
