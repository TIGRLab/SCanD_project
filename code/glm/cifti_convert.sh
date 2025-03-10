#! /bin/bash

module load connectome-workbench
base_dir='/scratch/ttan/ScanD_pipelines_scc/bin'
derivatives_dir='/scratch/ttan/ScanD_pipelines_scc/data/local/bids/derivatives/fmriprep'

echo "Changing directory to ${derivatives_dir} ..."
cd ${derivatives_dir}
for file in $(find -type f -name "*nbk*dtseries.nii"); 
do 
fname=$(basename $file | cut -d'_' -f1-6);
basedir=$(dirname $file)
echo "Running wb_command -cifti-convert -to-nifti ${file} ${basedir}/${fname}_bold.nii.gz..." | tee -a "${base_dir}/log_file.txt"
wb_command -cifti-convert -to-nifti ${file} ${basedir}/${fname}_bold.nii.gz >> "${base_dir}/log_file.txt" 2>&1
done

