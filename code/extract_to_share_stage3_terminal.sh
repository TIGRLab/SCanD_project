# A script to extract the bits that we want to share back with the corsotium
## magetbrain, gen_qsiprep_motion_metrics.py


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

PROJECT_DIR=$(dirname "${SCRIPT_DIR}")

module load apptainer/1.3.5

echo "Running qsiprep_metrics.csv"

## Generate qsiprep motion metrics and extract NODDI indices
module load NiaEnv/2019b python/3.6.8

# Create a directory for virtual environments if it doesn't exist
mkdir ${PROJECT_DIR}/../.virtualenvs
cd ${PROJECT_DIR}/../.virtualenvs
virtualenv --system-site-packages ${PROJECT_DIR}/../.virtualenvs/myenv

# Activate the virtual environment
source ${PROJECT_DIR}/../.virtualenvs/myenv/bin/activate

cd ${PROJECT_DIR}
python3 ${PROJECT_DIR}/code/gen_qsiprep_motion_metrics.py


if [ -d "${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep/qsiprep_metrics.csv" ];
then

echo "copying over qsiprep_metrics.csv"
rsync -a ${PROJECT_DIR}/data/local/derivatives/qsiprep/0.22.0/qsiprep/qsiprep_metrics.csv ${PROJECT_DIR}/data/share/qsiprep/0.22.0/

else

    echo "No qsiprep_metrics.csv found."

fi


# sharing magetbrain outputs
echo "Running magetbrain QC step"

mkdir -p ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/QC
singularity exec --cleanenv -B ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data:/data ${PROJECT_DIR}/containers/magetbrain.sif /bin/bash -c "export LANG=C.UTF-8 && export LC_ALL=C.UTF-8 && export LD_LIBRARY_PATH=/opt/minc/1.9.18/lib:\$LD_LIBRARY_PATH && collect_volumes.sh /data/output/fusion/majority_vote/*.mnc > /data/QC/volumes.csv"
source ${PROJECT_DIR}/code/magetbrain_QC.sh

mkdir -p ${PROJECT_DIR}/data/share/magetbrain/input
mkdir -p ${PROJECT_DIR}/data/share/magetbrain/fusion


if [ -d "${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/QC" ];
then

rsync -a ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/output/fusion/majority_vote/*labels.mnc ${PROJECT_DIR}/data/share/magetbrain/fusion
rsync -a ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/input/subjects/brains/*.mnc* ${PROJECT_DIR}/data/share/magetbrain/input
rsync -a ${PROJECT_DIR}/data/local/MAGeTbrain/magetbrain_data/QC ${PROJECT_DIR}/data/share/magetbrain/

else

    echo "No magetbrain QC folder found."

fi
