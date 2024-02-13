#!/bin/bash
#SBATCH --job-name=qsirecon
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=40
#SBATCH --time=20:00:00


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

# input is BIDS_DIR this is where the data downloaded from openneuro went
export BIDS_DIR=${BASEDIR}/data/local/bids

## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export QSIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/qsiprep_0.16.0RC3.simg

## setting up the output folders
export OUTPUT_DIR=${BASEDIR}/data/local/qsiprep  # use if version of fmriprep >=20.2
export QSIPREP_DIR=${BASEDIR}/data/local/qsiprep # use if version of fmriprep <=20.1

# export LOCAL_FREESURFER_DIR=${SCRATCH}/${STUDY}/data/derived/freesurfer-6.0.1
export WORK_DIR=${BBUFFER}/SCanD/qsiprep
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} # ${LOCAL_FREESURFER_DIR}

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
# Make sure FS_LICENSE is defined in the container.
export SINGULARITYENV_FS_LICENSE=/home/qsiprep/.freesurfer.txt


singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/qsiprep --home /home/qsiprep \
    -B ${BIDS_DIR}:/bids \
    -B ${QSIPREP_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    -B ${OUTPUT_DIR}:/out \
    ${SING_CONTAINER} \
    /bids /out participant \
    --skip-bids-validation \
    --participant_label ${SUBJECTS} \
    -w /work \
    --skip-bids-validation \
    --omp-nthreads 8 \
    --nthreads 40 \
    --recon-only \
    --recon-spec reorient_fslstd \
    --recon-input /derived \
    --output-resolution 2.0 


QSIRECON_OUT=${OUTPUT_DIR}/qsirecon/sub-${SUBJECTS}/ses-01/dwi/sub-${SUBJECTS}_ses-01_acq-singleshelldir60b1000_run-1_space-T1w_desc-preproc_fslstd
DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${SUBJECTS}/ses-01/dwi/sub-${SUBJECTS}_ses-01_acq-singleshelldir60b1000_run-1_space-T1w_desc-preproc_fslstd
DTIFIT_dir=$(dirname ${DTIFIT_OUT})
DTIFIT_name=$(basename ${DTIFIT_OUT})

mkdir -p $DTIFIT_dir


singularity exec \
  -H ${TMP_DIR} \
  -B ${QSIRECON_OUT}_dwi.nii.gz \
  -B ${QSIRECON_OUT}_mask.nii.gz \
  -B ${QSIRECON_OUT}_dwi.bvec \
  -B ${QSIRECON_OUT}_dwi.bval \
  -B ${DTIFIT_dir}:/out \
  ${SING_CONTAINER} \
  dtifit -k ${QSIRECON_OUT}_dwi.nii.gz \
  -m ${QSIRECON_OUT}_mask.nii.gz \
  -r ${QSIRECON_OUT}_dwi.bvec \
  -b ${QSIRECON_OUT}_dwi.bval \
  --save_tensor --sse \
  -o /out/$DTIFIT_name

 exitcode=$?

# Output results to a table
for subject in $SUBJECTS; do
    if [ $exitcode -eq 0 ]; then
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    0" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    else
        echo "sub-$subject   ${SLURM_ARRAY_TASK_ID}    qsirecon failed" \
            >> ${LOGS_DIR}/${SLURM_JOB_NAME}.${SLURM_ARRAY_JOB_ID}.tsv
    fi
done

##### STEP 3 - run the ENIGMA DTI participant workflow ########################

ENIGMA_DTI_OUT=${BASEDIR}/data/local/qsiprep/enigmaDTI

ENIGMA_CONTAINER=${SCRATCH}/SCanD_SPINS/containers/tbss.simg

mkdir -p ${ENIGMA_DTI_OUT}



singularity run \
  -H ${TMP_DIR} \
  -B ${ENIGMA_DTI_OUT}:/enigma_dir \
  -B ${DTIFIT_dir}:/dtifit_dir \
  ${ENIGMA_CONTAINER} \
  --calc-all --debug \
  /enigma_dir/sub-${SUBJECTS}_ses-01\
  /dtifit_dir/${DTIFIT_name}_FA.nii.gz



