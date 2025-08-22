#!/bin/bash
#SBATCH --job-name=qsirecon2
#SBATCH --output=logs/%x_%j.out 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=8
#SBATCH --time=02:00:00
#SBATCH --mem-per-cpu=4000

SUB_SIZE=1 ## number of subjects to run is 1 because there are multiple tasks/run that will run in parallel 
export THREADS_PER_COMMAND=2

BASEDIR=${SLURM_SUBMIT_DIR}

## cleanup on termination
function cleanup_ramdisk {
    echo -n "Cleaning up ramdisk directory /$SLURM_TMPDIR/ on "
    date
    rm -rf /$SLURM_TMPDIR
    echo -n "done at "
    date
}
trap "cleanup_ramdisk" TERM

module load apptainer/1.3.5

## input dirs
export BIDS_DIR=${BASEDIR}/data/local/bids
export QSIPREP_HOME=${BASEDIR}/templates
export ENIGMA_CONTAINER=${BASEDIR}/containers/tbss_2023-10-10.simg
export OUTPUT_DIR=${BASEDIR}/data/local
export QSIPREP_DIR=${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep
export WORK_DIR=${SLURM_TMPDIR}/SCanD/qsiprep
export LOGS_DIR=${BASEDIR}/logs
export fs_license=${BASEDIR}/templates/.freesurfer.txt
mkdir -vp ${OUTPUT_DIR} ${WORK_DIR}

## figure out subject allocation
bigger_bit=$(echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc)
N_SUBJECTS=$(( $(wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ') - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=$(sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${N_SUBJECTS} | tail -n ${Tail})
else
    SUBJECTS=$(sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE})
fi

for subj in $SUBJECTS; do
    SESSIONS=$(ls -d ${BIDS_DIR}/sub-${subj}/ses-*/ 2>/dev/null)

    if [ -z "$SESSIONS" ]; then
        ## no sessions
        for filename in ${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/dwi/*dwi.nii.gz; do
            [[ ! -f "$filename" ]] && continue

            acquisition=""; run=""
            [[ $filename =~ (acq-[^_]+) ]] && acquisition="${BASH_REMATCH[1]}"
            [[ $filename =~ (run-[0-9]+) ]] && run="${BASH_REMATCH[1]}"

            if [ -z "$acquisition" ] && [ -z "$run" ]; then
                QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/dwi/sub-${subj}_space-T1w_desc-preproc
                DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/dwi/sub-${subj}_space-T1w_desc-preproc
            elif [ -n "$acquisition" ] && [ -n "$run" ]; then
                QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/dwi/sub-${subj}_${acquisition}_${run}_space-T1w_desc-preproc
                DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/dwi/sub-${subj}_${acquisition}_${run}_space-T1w_desc-preproc
            elif [ -n "$acquisition" ]; then
                QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/dwi/sub-${subj}_${acquisition}_space-T1w_desc-preproc
                DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/dwi/sub-${subj}_${acquisition}_space-T1w_desc-preproc
            else
                QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/dwi/sub-${subj}_${run}_space-T1w_desc-preproc
                DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/dwi/sub-${subj}_${run}_space-T1w_desc-preproc
            fi

            ## dtifit
            DTIFIT_dir=$(dirname ${DTIFIT_OUT})
            DTIFIT_name=$(basename ${DTIFIT_OUT})
            mkdir -p $DTIFIT_dir

            apptainer exec \
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

            ## enigma
            ENIGMA_DTI_OUT=${BASEDIR}/data/local/enigmaDTI
            mkdir -p ${ENIGMA_DTI_OUT}
            apptainer run \
              -B ${ENIGMA_DTI_OUT}:/enigma_dir \
              -B ${DTIFIT_dir}:/dtifit_dir \
              ${ENIGMA_CONTAINER} \
              --calc-all --debug \
              /enigma_dir/sub-${subj} \
              /dtifit_dir/${DTIFIT_name}_FA.nii.gz
        done

    else
        ## with sessions
        for session in $SESSIONS; do
            session_name=$(basename $session)

            for filename in ${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/${session_name}/dwi/*dwi.nii.gz; do
                [[ ! -f "$filename" ]] && continue

                acquisition=""; run=""
                [[ $filename =~ (acq-[^_]+) ]] && acquisition="${BASH_REMATCH[1]}"
                [[ $filename =~ (run-[0-9]+) ]] && run="${BASH_REMATCH[1]}"

                if [ -z "$acquisition" ] && [ -z "$run" ]; then
                    QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_space-T1w_desc-preproc
                    DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_space-T1w_desc-preproc
                elif [ -n "$acquisition" ] && [ -n "$run" ]; then
                    QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_${acquisition}_${run}_space-T1w_desc-preproc
                    DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_${acquisition}_${run}_space-T1w_desc-preproc
                elif [ -n "$acquisition" ]; then
                    QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_${acquisition}_space-T1w_desc-preproc
                    DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_${acquisition}_space-T1w_desc-preproc
                else
                    QSIRECON_OUT=${OUTPUT_DIR}/qsirecon-FSL/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_${run}_space-T1w_desc-preproc
                    DTIFIT_OUT=${OUTPUT_DIR}/dtifit/sub-${subj}/${session_name}/dwi/sub-${subj}_${session_name}_${run}_space-T1w_desc-preproc
                fi

                ## dtifit
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

                ## enigma
                ENIGMA_DTI_OUT=${BASEDIR}/data/local/enigmaDTI
                mkdir -p ${ENIGMA_DTI_OUT}
                singularity run \
                  -B ${ENIGMA_DTI_OUT}:/enigma_dir \
                  -B ${DTIFIT_dir}:/dtifit_dir \
                  ${ENIGMA_CONTAINER} \
                  --calc-all --debug \
                  /enigma_dir/sub-${subj}_${session_name} \
                  /dtifit_dir/${DTIFIT_name}_FA.nii.gz
            done
        done
    fi

    ## nipoppy tracker
    export APPTAINERENV_ROOT_DIR=${BASEDIR}
    singularity exec \
        --bind ${SCRATCH}:${SCRATCH} \
        --env SUBJECTS="$subj" \
        ${BASEDIR}/containers/nipoppy.sif /bin/bash -c '
        set -euo pipefail
        cd "${ROOT_DIR}/Neurobagel"

        mkdir -p derivatives/qsirecon2/0.22.0/output/
        ln -s "${ROOT_DIR}/data/local/dtifit/" derivatives/qsirecon2/0.22.0/output/ || true
        ln -s "${ROOT_DIR}/data/local/enigmaDTI/" derivatives/qsirecon2/0.22.0/output/ || true

        nipoppy track \
          --pipeline qsirecon2 \
          --pipeline-version 0.22.0 \
          --participant-id sub-'$subj'
        '
    unset APPTAINERENV_ROOT_DIR
done
