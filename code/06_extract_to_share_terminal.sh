# A script to extract the bits that we want to share back with the corsotium
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..


## Generate qsiprep motion metrics and extract NODDI indices
module load NiaEnv/2019b python/3.6.8

# Create a directory for virtual environments if it doesn't exist
mkdir ${BASEDIR}/../.virtualenvs
cd ${BASEDIR}/../.virtualenvs
virtualenv --system-site-packages ${BASEDIR}/../.virtualenvs/myenv

# Activate the virtual environment
source ${BASEDIR}/../.virtualenvs/myenv/bin/activate

cd ${BASEDIR}
python3 ${BASEDIR}/code/gen_qsiprep_motion_metrics.py

mkdir -p ${BASEDIR}/data/share/qsiprep/0.22.0/
rsync -a ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep/qsiprep_metrics.csv ${BASEDIR}/data/share/qsiprep/0.22.0/

# sharing magetbrain outputs
mkdir -p ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/QC
singularity exec --cleanenv -B ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data:/data ${BASEDIR}/containers/magetbrain.sif /bin/bash -c "export LANG=C.UTF-8 && export LC_ALL=C.UTF-8 && export LD_LIBRARY_PATH=/opt/minc/1.9.18/lib:\$LD_LIBRARY_PATH && collect_volumes.sh /data/output/fusion/majority_vote/*.mnc > /data/QC/volumes.csv"
source ${BASEDIR}/code/magetbrain_QC.sh

mkdir -p ${BASEDIR}/data/share/magetbrain/input
mkdir -p ${BASEDIR}/data/share/magetbrain/fusion

rsync -a ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/output/fusion/majority_vote/*labels.mnc ${BASEDIR}/data/share/magetbrain/fusion
rsync -a ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/input/subjects/brains/*.mnc* ${BASEDIR}/data/share/magetbrain/input
rsync -a ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/QC ${BASEDIR}/data/share/magetbrain/
