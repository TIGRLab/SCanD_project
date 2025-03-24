# A script to extract the bits that we want to share back with the corsotium


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PROJECT_DIR=$(dirname "${SCRIPT_DIR}")


## Generate qsiprep motion metrics and extract NODDI indices
module load NiaEnv/2019b python/3.6.8

# Create a directory for virtual environments if it doesn't exist
mkdir ${PROJECT_DIR}/../.virtualenvs
cd ${PROJECT_DIR}/../.virtualenvs
virtualenv --system-site-packages ${PROJECT_DIR}/../.virtualenvs/myenv

# Activate the virtual environment
source ${PROJECT_DIR}/../.virtualenvs/myenv/bin/activate

python3 ${PROJECT_DIR}/code/gen_qsiprep_motion_metrics.py

rsync -a ${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep/qsiprep_metrics.csv ${PROJECT_DIR}/data/share/qsiprep/0.22.0/

rsync -a --include='noddi_roi/' --include='noddi_roi/**/' --include='noddi_roi/**/*.png' --include='noddi_roi/**/*.csv' --exclude='noddi_roi/**' \
    ${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI/ \
    ${PROJECT_DIR}/data/share/amico_noddi

# sharing magetbrain outputs
mkdir -p ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/QC
singularity exec --cleanenv -B ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data:/data ${PROJECT_DIR}/containers/magetbrain.sif /bin/bash -c "export LANG=C.UTF-8 && export LC_ALL=C.UTF-8 && export LD_LIBRARY_PATH=/opt/minc/1.9.18/lib:\$LD_LIBRARY_PATH && collect_volumes.sh /data/output/fusion/majority_vote/*.mnc > /data/QC/volumes.csv"
source ${PROJECT_DIR}/code/magetbrain_QC.sh

mkdir -p ${PROJECT_DIR}/data/share/magetbrain/input
mkdir -p ${PROJECT_DIR}/data/share/magetbrain/fusion

rsync -a ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/output/fusion/majority_vote/*labels.mnc ${PROJECT_DIR}/data/share/magetbrain/fusion
rsync -a ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/input/subjects/brains/*.mnc* ${PROJECT_DIR}/data/share/magetbrain/input
rsync -a ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/QC ${PROJECT_DIR}/data/share/magetbrain/
