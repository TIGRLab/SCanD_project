BASEDIR=$SCRATCH/SCanD_project

export BIDS_DIR=${BASEDIR}/data/local/bids
export QSIPREP_DIR=${BASEDIR}/data/local/qsiprep/0.21.4
export SING_CONTAINER=${BASEDIR}/containers/qsiprep-0.21.4.sif
export OUTPUT_DIR=${BASEDIR}/data/local/amico_noddi
export TMP_DIR=${BASEDIR}/data/local/amico_noddi/tmp
export WORK_DIR=${BBUFFER}/SCanD/amico
export LOGS_DIR=${BASEDIR}/logs
export SINGULARITYENV_FS_LICENSE=${BASEDIR}/templates/.freesurfer.txt

PARTICIPANTS=$(tail -n +2 data/local/bids/participants.tsv | cut -f1)

# Loop through each participant ID
for SUBJECT in $PARTICIPANTS; do
  echo "Processing participant: $SUBJECT"
   xvfb-run singularity run\
    -H ${TMP_DIR} \
    -B ${BIDS_DIR}:/bids \
    -B ${QSIPREP_DIR}:/qsiprep \
    -B ${OUTPUT_DIR}:/out \
    -B ${WORK_DIR}:/work \
    -B ${SINGULARITYENV_FS_LICENSE}:/li \
    ${SING_CONTAINER} \
    /bids /out participant \
    --skip-bids-validation \
    --participant_label ${SUBJECT} \
    --recon-only \
    --recon-spec amico_noddi \
    --recon-input /qsiprep \
    --n_cpus 4 --omp-nthreads 2 \
    --output-resolution 1.7 \
    --fs-license-file /li \
    -w /work \
    --notrack
done
