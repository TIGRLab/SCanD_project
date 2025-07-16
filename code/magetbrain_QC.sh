BASEDIR=$PWD

subjects_dir="${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/input/subjects/brains"
output_dir="${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/output/fusion/majority_vote"
qc_dir="${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/QC"

for input_file in "$subjects_dir"/sub*.mnc; do
    filename=$(basename "$input_file" .mnc)

    output_file="${output_dir}/${filename}_labels.mnc"

    if [[ ! -f "$output_file" ]]; then
        echo "WARNING: No output file found for ${output_file}"
        continue
    fi

    qc_file="${qc_dir}/${filename}.jpg"
    
    singularity exec --cleanenv --writable-tmpfs -B ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data:/data \
    ${BASEDIR}/containers/magetbrain.sif /bin/bash -c "
      mkdir -p /opt/minc/1.9.18/share/mni-models;
      export PERL5LIB=/opt/minc/1.9.18/perl:\$PERL5LIB;
      ln -s /opt/minc/1.9.18/share/ILT /opt/minc/1.9.18/share/mni-models/ILT;
      MAGeT-QC.sh /data/input/subjects/brains/$(basename "$input_file") \
                  /data/output/fusion/majority_vote/$(basename "$output_file") \
                  /data/QC/$(basename "$qc_file")"
done
