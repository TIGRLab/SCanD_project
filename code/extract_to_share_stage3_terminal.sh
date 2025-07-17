#!/bin/bash
## magetbrain, gen_qsiprep_motion_metrics.py
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..


module load apptainer/1.3.5

echo "Running qsiprep_metrics.csv"

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


if [ -d "${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep/qsiprep_metrics.csv" ];
then

echo "copying over qsiprep_metrics.csv"
rsync -a ${BASEDIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep/qsiprep_metrics.csv ${BASEDIR}/data/share/qsiprep/0.22.0/

else

    echo "No qsiprep_metrics.csv found."

fi


# sharing magetbrain outputs
echo "Running magetbrain QC step"

mkdir -p ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/QC
singularity exec --cleanenv -B ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data:/data ${BASEDIR}/containers/magetbrain.sif /bin/bash -c "export LANG=C.UTF-8 && export LC_ALL=C.UTF-8 && export LD_LIBRARY_PATH=/opt/minc/1.9.18/lib:\$LD_LIBRARY_PATH && collect_volumes.sh /data/output/fusion/majority_vote/*.mnc > /data/QC/volumes.csv"
source ${BASEDIR}/code/magetbrain_QC.sh

mkdir -p ${BASEDIR}/data/share/magetbrain/input
mkdir -p ${BASEDIR}/data/share/magetbrain/fusion


if [ -d "${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/QC" ];
then

rsync -a ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/output/fusion/majority_vote/*labels.mnc ${BASEDIR}/data/share/magetbrain/fusion
rsync -a ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/input/subjects/brains/*.mnc* ${BASEDIR}/data/share/magetbrain/input
rsync -a ${BASEDIR}/data/local/derivatives/MAGeTbrain/magetbrain_data/QC ${BASEDIR}/data/share/magetbrain/

else

    echo "No magetbrain QC folder found."

fi
