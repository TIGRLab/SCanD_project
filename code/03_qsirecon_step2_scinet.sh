#!/bin/bash
#SBATCH --job-name=qsirecon2
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=192
#SBATCH --time=01:00:00


SUB_SIZE=1 ## number of subjects to run is 1 because there are multiple tasks/run that will run in parallel 
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
export ENIGMA_CONTAINER=${BASEDIR}/containers/tbss_2023-10-10.simg

## setting up the output folders
export OUTPUT_DIR=${BASEDIR}/data/local  # use if version of fmriprep >=20.2
export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep # use if version of fmriprep <=20.1

# export LOCAL_FREESURFER_DIR=${SCRATCH}/${STUDY}/data/derived/freesurfer-6.0.1
export WORK_DIR=${SLURM_TMPDIR}/SCanD/qsiprep
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

export fs_license=${BASEDIR}/templates/.freesurfer.txt

    
# Get list of sessions for the subject
SESSIONS=$(ls -d ${BIDS_DIR}/sub-${SUBJECTS}/ses-*/)

# Check if there are any sessions for the subject
if [ -z "$SESSIONS" ]; then

 filename=$(ls -1 ${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/dwi/*.nii.gz | head -n 1)

        if [[ $filename =~ (acq-.+?)_space ]]; then
            acquisition="${BASH_REMATCH[1]}"
        else
            acquisition=""
        fi

        if [[ $filename =~ run-(\d+)_space ]]; then
            run="run-${BASH_REMATCH[1]}"
        else
            run=""
        fi

    # Run the code without session
    if [ -z "$acquisition" ]; then
        if [ -z "$run" ]; then 
            QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/dwi/sub-${SUBJECTS}_space-T1w_desc-preproc
            DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${SUBJECTS}/dwi/sub-${SUBJECTS}_space-T1w_desc-preproc
        else
            QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/dwi/sub-${SUBJECTS}_${run}_space-T1w_desc-preproc
            DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${SUBJECTS}/dwi/sub-${SUBJECTS}_${run}_space-T1w_desc-preproc
        fi
    else
            QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/dwi/sub-${SUBJECTS}_${acquisition}_space-T1w_desc-preproc
            DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${SUBJECTS}/dwi/sub-${SUBJECTS}_${acquisition}_space-T1w_desc-preproc
    fi


    DTIFIT_dir=$(dirname ${DTIFIT_OUT})
    DTIFIT_name=$(basename ${DTIFIT_OUT})

    mkdir -p $DTIFIT_dir

    singularity exec \
      -B ${QSIRECON_OUT}_dwi.nii.gz \
      -B ${QSIRECON_OUT}_dwimap.nii.gz \
      -B ${QSIRECON_OUT}_dwi.bvec \
      -B ${QSIRECON_OUT}_dwi.bval \
      -B ${DTIFIT_dir}:/out \
      ${ENIGMA_CONTAINER} \
      dtifit -k ${QSIRECON_OUT}_dwi.nii.gz \
      -m ${QSIRECON_OUT}_dwimap.nii.gz \
      -r ${QSIRECON_OUT}_dwi.bvec \
      -b ${QSIRECON_OUT}_dwi.bval \
      --save_tensor --sse \
      -o ${DTIFIT_dir}/$DTIFIT_name

    ENIGMA_DTI_OUT=${BASEDIR}/data/local/enigmaDTI

    mkdir -p ${ENIGMA_DTI_OUT}

    singularity run \
      -B ${ENIGMA_DTI_OUT}:/enigma_dir \
      -B ${DTIFIT_dir}:/dtifit_dir \
      ${ENIGMA_CONTAINER} \
      --calc-all --debug \
      /enigma_dir/sub-${SUBJECTS} \
      /dtifit_dir/${DTIFIT_name}_FA.nii.gz
      

    ## nipoppy trackers 
    
    singularity exec \
  	--env BASEDIR="$BASEDIR" \
    --bind $BASEDIR:$BASEDIR \
  	--env SUBJECTS="$SUBJECTS" \
  	${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    	set -euo pipefail

    	cd "$BASEDIR/Neurobagel"
    
    	mkdir -p derivatives/qsirecon2/0.22.0/output/
    	ls -al derivatives/qsirecon2/0.22.0/output/

    	ln -s "$BASEDIR/data/local/dtifit/" derivatives/qsirecon2/0.22.0/output/ || true
        ls -al derivatives/qsirecon2/0.22.0/output/
    	ln -s "$BASEDIR/data/local/enigmaDTI/" derivatives/qsirecon2/0.22.0/output/ || true

    	for subject in $SUBJECTS; do
      	nipoppy track \
        	--pipeline qsirecon2 \
        	--pipeline-version 0.22.0 \
        	--participant-id sub-$subject
    	done
  	'


else

    for session in $SESSIONS; do
        session_name=$(basename $session)
        filename=$(ls -1 ${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/${session_name}/dwi/*.nii.gz | head -n 1)

        if [[ $filename =~ (acq-.+?)_space ]]; then
            acquisition="${BASH_REMATCH[1]}"
        else
            acquisition=""
        fi

        if [[ $filename =~ run-(\d+)_space ]]; then
            run="run-${BASH_REMATCH[1]}"
        else
            run=""
        fi

        if [ -z "$acquisition" ]; then
            if [ -z "$run" ]; then
                QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/${session_name}/dwi/sub-${SUBJECTS}_${session_name}_space-T1w_desc-preproc
                DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${SUBJECTS}/${session_name}/dwi/sub-${SUBJECTS}_${session_name}_space-T1w_desc-preproc
            else
                QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/${session_name}/dwi/sub-${SUBJECTS}_${session_name}_${run}_space-T1w_desc-preproc
                DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${SUBJECTS}/${session_name}/dwi/sub-${SUBJECTS}_${session_name}_${run}_space-T1w_desc-preproc
            fi
        else
                QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${SUBJECTS}/${session_name}/dwi/sub-${SUBJECTS}_${session_name}_${acquisition}_space-T1w_desc-preproc
                DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${SUBJECTS}/${session_name}/dwi/sub-${SUBJECTS}_${session_name}_${acquisition}_space-T1w_desc-preproc   
        fi

    

        DTIFIT_dir=$(dirname ${DTIFIT_OUT})
        DTIFIT_name=$(basename ${DTIFIT_OUT})

        mkdir -p $DTIFIT_dir

        singularity exec \
          -B ${QSIRECON_OUT}_dwi.nii.gz \
          -B ${QSIRECON_OUT}_dwimap.nii.gz \
          -B ${QSIRECON_OUT}_dwi.bvec \
          -B ${QSIRECON_OUT}_dwi.bval \
          -B ${DTIFIT_dir}:/out \
          ${ENIGMA_CONTAINER} \
          dtifit -k ${QSIRECON_OUT}_dwi.nii.gz \
          -m ${QSIRECON_OUT}_dwimap.nii.gz \
          -r ${QSIRECON_OUT}_dwi.bvec \
          -b ${QSIRECON_OUT}_dwi.bval \
          --save_tensor --sse \
          -o ${DTIFIT_dir}/$DTIFIT_name

        ENIGMA_DTI_OUT=${BASEDIR}/data/local/enigmaDTI

        mkdir -p ${ENIGMA_DTI_OUT}

        singularity run \
          -B ${ENIGMA_DTI_OUT}:/enigma_dir \
          -B ${DTIFIT_dir}:/dtifit_dir \
          ${ENIGMA_CONTAINER} \
          --calc-all --debug \
          /enigma_dir/sub-${SUBJECTS}_${session_name} \
          /dtifit_dir/${DTIFIT_name}_FA.nii.gz


    ## nipoppy trackers 
    
    singularity exec \
  	--env BASEDIR="$BASEDIR" \
    --bind $BASEDIR:$BASEDIR \
  	--env SUBJECTS="$SUBJECTS" \
  	${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
    	set -euo pipefail

    	cd "$BASEDIR/Neurobagel"
    
    	mkdir -p derivatives/qsirecon2/0.22.0/output/
    	ls -al derivatives/qsirecon2/0.22.0/output/

    	ln -s "$BASEDIR/data/local/dtifit/" derivatives/qsirecon2/0.22.0/output/ || true
        ls -al derivatives/qsirecon2/0.22.0/output/
    	ln -s "$BASEDIR/data/local/enigmaDTI/" derivatives/qsirecon2/0.22.0/output/ || true

    	for subject in $SUBJECTS; do
      	nipoppy track \
        	--pipeline qsirecon2 \
        	--pipeline-version 0.22.0 \
        	--participant-id sub-$subject
    	done
  	'

    done
   
fi
