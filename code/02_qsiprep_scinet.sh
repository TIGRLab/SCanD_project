#!/bin/bash
#SBATCH --job-name=qsiprep
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=15
#SBATCH --time=06:00:00
#SBATCH --mem-per-cpu=10000

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

module load apptainer/1.3.5
# input is BIDS_DIR this is where the data downloaded from openneuro went
export BIDS_DIR=${BASEDIR}/data/local/bids

## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export QSIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/qsiprep-0.22.0.sif

## setting up the output folders
# export OUTPUT_DIR=${BASEDIR}/data/local/fmriprep  # use if version of fmriprep >=20.2
export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0 # use if version of fmriprep <=20.1

# adding random string (project_id) to BBUFFER folder to prevent conflicts betwwen projects
export WORK_DIR=${SCRATCH}/SCanD/qsiprep
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


# Extract voxel sizes using fslinfo
first_session=$(find "${BIDS_DIR}/sub-${SUBJECTS}" -maxdepth 1 -type d -name 'ses-*' | head -n 1)

if [ -n "$(find "${BIDS_DIR}/sub-${SUBJECTS}" -maxdepth 1 -type d -name 'ses-*' -print -quit)" ]; then
voxel_info=$(singularity exec -B ${BASEDIR}/data/local/bids:/bids -B ${first_session}:/first_session containers/qsiprep-0.22.0.sif fslinfo /first_session/dwi/*.nii.gz)
else
voxel_info=$(singularity exec -B ${BASEDIR}/data/local/bids:/bids containers/qsiprep-0.22.0.sif fslinfo /bids/sub-${SUBJECTS}/dwi/*.nii.gz)
fi

# Extract voxel dimensions
voxdim1=$(echo "$voxel_info" | grep -oP 'pixdim1\s+\K\S+')
voxdim2=$(echo "$voxel_info" | grep -oP 'pixdim2\s+\K\S+')
voxdim3=$(echo "$voxel_info" | grep -oP 'pixdim3\s+\K\S+')

# Make all numbers positive and round to one decimal place
voxdim1=$(printf "%.1f" $voxdim1)
voxdim2=$(printf "%.1f" $voxdim2)
voxdim3=$(printf "%.1f" $voxdim3)

# Calculate the sum of voxel dimensions
sum=$(bc <<< "$voxdim1 + $voxdim2 + $voxdim3")
# Calculate the average
average=$(bc -l <<< "$sum / 3")
# Round the average to one decimal place
RESOLUTION=$(printf "%.1f" $average)


## set singularity environment variables that will point to the freesurfer license and the templateflow bits
# Make sure FS_LICENSE is defined in the container.
export SINGULARITYENV_FS_LICENSE=/home/qsiprep/.freesurfer.txt

singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/qsiprep --home /home/qsiprep \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${WORK_DIR}:/work \
    ${SING_CONTAINER} \
    /bids /derived participant \
    --participant_label ${SUBJECTS} \
    -w /work \
    --skip-bids-validation \
    --omp-nthreads 8 \
    --nthreads 40 \
    --mem-mb 15000 \
    --denoise-method dwidenoise \
    --unringing-method mrdegibbs \
    --separate_all_dwis \
    --hmc_model eddy \
    --output-resolution ${RESOLUTION}\
    --use-syn-sdc \
    --force-syn


## nipoppy trackers 

cd ${BASEDIR}/Neurobagel

source ../nipoppy/bin/activate

mkdir -p derivatives/qsiprep/0.22.0/output/
ls -al derivatives/qsiprep/0.22.0/output/

ln -s ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep/*  derivatives/qsiprep/0.22.0/output/

for subject in $SUBJECTS; do
	nipoppy track  --pipeline qsiprep   --pipeline-version 0.22.0 --participant-id sub-$subject
done
