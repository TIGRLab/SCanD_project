#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=80
#SBATCH --time=00:30:00
#SBATCH --export=ALL
#SBATCH --job-name="cifti_anatparc"
#SBATCH --output=logs/cifti_anatparc_%j.txt

## set the second environment variable to get the base directory
BASEDIR=${SLURM_SUBMIT_DIR}

## this script requires gnu-parallel
module load gnu-parallel/20191122

## note the dlabel file path must be a relative to the output folder
export parcellation_dir=${BASEDIR}/templates/parcellations
export atlases="atlas-Glasser"

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


## these folders envs need to be set up for this script to run properly 
## see notebooks/00_setting_up_envs.md for the set up instructions
export SING_CONTAINER=${BASEDIR}/container/fmriprep_ciftity-v1.3.2-2.3.3.simg

# mkdir -vp ${OUTPUT_DIR} ${WORK_DIR} ${LOGS_DIR} # ${LOCAL_FREESURFER_DIR}

export fmriprep_folder="${BASEDIR}/data/local/fmriprep/"
export ciftify_folder="${BASEDIR}/data/local/ciftify/"

export cifti_dense_anat="${BASEDIR}/data/local/cifti_dense_anat/"
export parcellated="${BASEDIR}/data/local/parcellated_2/"

## get the subject list from a combo of the array id, the participants.tsv and the chunk size
SUB_SIZE=1 ## number of subjects to run
bigger_bit=`echo "($SLURM_ARRAY_TASK_ID + 1) * ${SUB_SIZE}" | bc`

N_SUBJECTS=$(( $( wc -l ${BIDS_DIR}/participants.tsv | cut -f1 -d' ' ) - 1 ))
array_job_length=$(echo "$N_SUBJECTS/${SUB_SIZE}" | bc)
Tail=$((N_SUBJECTS-(array_job_length*SUB_SIZE)))

if [ "$SLURM_ARRAY_TASK_ID" -eq "$array_job_length" ]; then
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv  | head -n ${N_SUBJECTS} | tail -n ${Tail}`
else
    SUBJECTS=`sed -n -E "s/sub-(\S*)\>.*/\1/gp" ${BIDS_DIR}/participants.tsv | head -n ${bigger_bit} | tail -n ${SUB_SIZE}`
fi

run_parcellation() {

    sub=${1}

    sing_home=$(mktemp -d -t wb-XXXXXXXXXX)
    hemi_anat=$(mktemp -d -t hemi-XXXXXXXXXX)

    for atlas in ${atlases}; do

      mkdir -p ${parcellated}/${atlas}/ptseries/${sub}/anat
      mkdir -p ${parcellated}/${atlas}/csv/${sub}/anat
      
      echo "parcellating thickness using ${atlas}"
  
      # parcellate to a ptseries file
      singularity exec \
      -H ${sing_home} \
      -B ${ciftify_folder}:/ciftify \
      -B ${parcellated}:/parcellated \
      -B ${parcellation_dir}:/parcellations \
      ${SING_CONTAINER} \
      wb_command -cifti-parcellate \
      /ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.thickness.32k_fs_LR.dscalar.nii \
      /parcellations/tpl-fsLR_res-91k_${atlas}_dseg.dlabel.nii \
      COLUMN \
      /parcellated/${atlas}/ptseries/${sub}/anat/${sub}_${atlas}_thickness.pscalar.nii \
      -include-empty
    
    done
    
    mkdir -p ${parcellated}/atlas-aparc/ptseries/${sub}/anat
    mkdir -p ${parcellated}/atlas-aparc/csv/${sub}/anat
    
    # parcellate to a pscalar file using the aparc atlas
    echo "parcellating thickness using aparc atlas"
    singularity exec \
    -H ${sing_home} \
    -B ${ciftify_folder}:/ciftify \
    -B ${parcellated}:/parcellated \
    ${SING_CONTAINER} \
    wb_command -cifti-parcellate \
    /ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.thickness.32k_fs_LR.dscalar.nii \
    /ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.aparc.32k_fs_LR.dlabel.nii \
    COLUMN \
    /parcellated/atlas-aparc/ptseries/${sub}/anat/${sub}_atlas-aparc_thickness.pscalar.nii \
    -include-empty 


    
    for hemi in L R; do
    
      # calculate surface area from midthickness
      echo "calculating surface area for ${hemi} hemisphere"
      singularity exec \
        -H ${sing_home} \
        -B ${ciftify_folder}:/ciftify \
        -B ${hemi_anat}:/hemi_anat \
        ${SING_CONTAINER} \
          wb_command -surface-vertex-areas \
          /ciftify/${sub}/T1w/fsaverage_LR32k/${sub}.${hemi}.midthickness.32k_fs_LR.surf.gii \
          /hemi_anat/${sub}_space-fsLR_den-91k_hemi-${hemi}_surfacearea.shape.gii
          
      ## calculate wedge volume from white and pial surface
      echo "calculating wedge volumme for ${hemi} hemisphere"
      singularity exec \
        -H ${sing_home} \
        -B ${ciftify_folder}:/ciftify \
        -B ${hemi_anat}:/hemi_anat \
        ${SING_CONTAINER} \
        wb_command -surface-wedge-volume \
           /ciftify/${sub}/T1w/fsaverage_LR32k/${sub}.${hemi}.white.32k_fs_LR.surf.gii \
           /ciftify/${sub}/T1w/fsaverage_LR32k/${sub}.${hemi}.pial.32k_fs_LR.surf.gii \
           /hemi_anat/${sub}_space-fsLR_den-91k_hemi-${hemi}_volume.shape.gii
    done
    
    mkdir -p ${cifti_dense_anat}/${sub}/anat    
    
    for metric in volume surfacearea; do
    
      echo "combining ${metric} to dense pscalar"
      singularity exec \
        -H ${sing_home} \
        -B ${ciftify_folder}:/ciftify \
        -B ${hemi_anat}:/hemi_anat \
        -B ${cifti_dense_anat}:/cifti_dense_anat \
        -B ${parcellated}:/parcellated \
        -B ${parcellation_dir}:/parcellations \
        ${SING_CONTAINER} \
           wb_command -cifti-create-dense-scalar \
           /cifti_dense_anat/${sub}/anat/${sub}_space-fsLR_den-91k_${metric}.dscalar.nii \
          -left-metric /hemi_anat/${sub}_space-fsLR_den-91k_hemi-L_${metric}.shape.gii \
          -roi-left /ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.L.atlasroi.32k_fs_LR.shape.gii \
          -right-metric /hemi_anat/${sub}_space-fsLR_den-91k_hemi-R_${metric}.shape.gii \
          -roi-right /ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.R.atlasroi.32k_fs_LR.shape.gii
        
      for atlas in ${atlases}; do
      
        echo "parcellating ${atlas} ${metric} ptseries to using sum"
        
        # parcellate to a ptseries file with the given atlas
        singularity exec \
        -H ${sing_home} \
        -B ${ciftify_folder}:/ciftify \
        -B ${cifti_dense_anat}:/cifti_dense_anat \
        -B ${parcellated}:/parcellated \
        -B ${parcellation_dir}:/parcellations \
        ${SING_CONTAINER} \
        wb_command -cifti-parcellate \
        /cifti_dense_anat/${sub}/anat/${sub}_space-fsLR_den-91k_${metric}.dscalar.nii \
        /parcellations/tpl-fsLR_res-91k_${atlas}_dseg.dlabel.nii \
        COLUMN \
        /parcellated/${atlas}/ptseries/${sub}/anat/${sub}_${atlas}_${metric}.pscalar.nii \
        -include-empty \
        -method SUM
        
      done
        
    # parcellate to a pscalar file using the aparc atlas
    
    echo "parcellating aparc ${metric} ptseries to using sum"
    singularity exec \
    -H ${sing_home} \
    -B ${ciftify_folder}:/ciftify \
    -B ${cifti_dense_anat}:/cifti_dense_anat \
    -B ${parcellated}:/parcellated \
    ${SING_CONTAINER} \
    wb_command -cifti-parcellate \
    /cifti_dense_anat/${sub}/anat/${sub}_space-fsLR_den-91k_${metric}.dscalar.nii \
    /ciftify/${sub}/MNINonLinear/fsaverage_LR32k/${sub}.aparc.32k_fs_LR.dlabel.nii \
    COLUMN \
    /parcellated/atlas-aparc/ptseries/${sub}/anat/${sub}_atlas-aparc_${metric}.pscalar.nii \
    -include-empty \
    -method SUM
      
    done
    
    
    for metric in volume surfacearea thickness; do

      for atlas in ${atlases} atlas-aparc; do
      
      # convert the ptseries to a csv
      echo "converting ${atlas} ${metric} ptseries to csv"
      singularity exec \
      -H ${sing_home} \
      -B ${parcellated}:/parcellated \
      ${SING_CONTAINER} wb_command -cifti-convert -to-text \
      /parcellated/${atlas}/ptseries/${sub}/anat/${sub}_${atlas}_${metric}.pscalar.nii \
      /parcellated/${atlas}/csv/${sub}/anat/${sub}_${atlas}_${metric}.csv \
      -col-delim ","
      
      done
      
    done
  
    rm -r ${sing_home}

}

export -f run_parcellation

parallel -j ${SUB_SIZE} --tag --line-buffer --compress \
 "run_parcellation {1}" \
    ::: ${SUBJECTS}
