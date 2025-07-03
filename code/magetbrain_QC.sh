BASEDIR=$PWD

subjects_dir="${BASEDIR}/data/local/MAGeTbrain/magetbrain_data/input/subjects/brains"
output_dir="${BASEDIR}/data/local/MAGeTbrain/magetbrain_data/output/fusion/majority_vote"
qc_dir="${BASEDIR}/data/local/MAGeTbrain/magetbrain_data/QC"

for input_file in $subjects_dir/sub*.mnc; do
    # Extract the base subject ID (with or without session)
    subj_id=$(basename "$input_file" | cut -d'_' -f1-2)
    
    # Check if the subject ID contains a session (i.e., '_ses-')
    if [[ "$subj_id" == *"ses-"* ]]; then
        # For subjects with sessions, extract the session part as well
        subj_id_base=$(basename "$input_file" | cut -d'_' -f1-2)  # e.g., sub-CMH00000001_ses-01
    else
        # For subjects without sessions, just use the first part
        subj_id_base=$(basename "$input_file" | cut -d'_' -f1)  # e.g., sub-CMH00000001
    fi
    
    output_file="$output_dir/${subj_id_base}_*labels.mnc"
    output_file=$(echo $output_file)  # Expand the wildcard   
    qc_file="$qc_dir/$(basename "$input_file" .mnc).jpg"
    
    singularity exec --cleanenv --writable-tmpfs -B ${BASEDIR}/data/local/MAGeTbrain/magetbrain_data:/data \
    ${BASEDIR}/containers/magetbrain.sif /bin/bash -c "
      mkdir -p /opt/minc/1.9.18/share/mni-models;
      export PERL5LIB=/opt/minc/1.9.18/perl:\$PERL5LIB;
      ln -s /opt/minc/1.9.18/share/ILT /opt/minc/1.9.18/share/mni-models/ILT;
      MAGeT-QC.sh /data/input/subjects/brains/$(basename $input_file) \
                  /data/output/fusion/majority_vote/$(basename $output_file) \
                  /data/QC/${subj_id_base}.jpg"
       
done

