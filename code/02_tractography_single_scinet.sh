#!/bin/bash
#SBATCH --job-name=tractography
#SBATCH --output=logs/%x_%j.out
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=20:00:00
#SBATCH --mem-per-cpu=4000

SUB_SIZE=1
export THREADS_PER_COMMAND=2


BASEDIR=${SLURM_SUBMIT_DIR}

function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}

trap "cleanup_ramdisk" TERM
module load apptainer/1.3.5

export BIDS_DIR=${BASEDIR}/data/local/bids

export QSIPREP_HOME=${BASEDIR}/templates
export SING_CONTAINER=${BASEDIR}/containers/qsiprep-0.22.0.sif

export OUTPUT_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/tractography # use if version of fmriprep <=20.1

export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep
export FREESURFER_DIR=${BASEDIR}/data/local/derivatives/fmriprep/25.2.4/sourcedata/freesurfer

# Create subject-only symlinks (remove _ses* suffix)
for d in ${FREESURFER_DIR}/sub-*_ses-*; do
  subj="${d%%_ses-*}"      # strips _ses-XX
  ln -sfn "$d" "$subj"
done

export WORK_DIR=${SLURM_TMPDIR}/SCanD/qsiprep
export LOGS_DIR=${BASEDIR}/logs
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR}

bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

export ORIG_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

singularity run --cleanenv \
    -B ${BASEDIR}/templates:/home/qsiprep --home /home/qsiprep \
    -B ${BIDS_DIR}:/bids \
    -B ${OUTPUT_DIR}:/derived \
    -B ${QSIPREP_DIR}:/qsiprep \
    -B ${FREESURFER_DIR}:/freesurfer \
    -B ${WORK_DIR}:/work \
    -B ${ORIG_FS_LICENSE}:/li\
    ${SING_CONTAINER} \
    /bids /derived participant \
    --participant_label ${SUBJECTS} \
    --skip_bids_validation \
    -w /work \
    --recon_only \
    --recon_input /qsiprep \
    --recon_spec mrtrix_singleshell_ss3t_ACT-hsvs \
    --freesurfer-input /freesurfer \
    --fs-license-file /li \
    --skip-odf-reports \
    --output-resolution 2.0


## nipoppy trackers

singularity exec \
  --env BASEDIR="$BASEDIR" \
  --bind ${BASEDIR}:${BASEDIR} \
  --env SUBJECTS="$SUBJECTS" \
  ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    set -euo pipefail

    cd "$BASEDIR/Neurobagel"

    mkdir -p derivatives/tractographysingle/0.22.0/output/
    ls -al derivatives/tractographysingle/0.22.0/output/

    ln -s "$BASEDIR/data/local/derivatives/qsiprep/0.22.0/tractography/qsirecon-MRtrix3_fork-SS3T_act-HSVS/" derivatives/tractographysingle/0.22.0/output/ || true

    for subject in $SUBJECTS; do
      nipoppy track \
        --pipeline tractographysingle \
        --pipeline-version 0.22.0 \
        --participant-id sub-$subject
    done
  '
