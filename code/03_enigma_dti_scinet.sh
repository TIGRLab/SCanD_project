module load NiaEnv/2019b python/3.11.5

# Create a directory for virtual environments if it doesn't exist
mkdir ~/.virtualenvs
cd ~/.virtualenvs
virtualenv --system-site-packages ~/.virtualenvs/myenv

# Activate the virtual environment
source ~/.virtualenvs/myenv/bin/activate 


python3 -m pip install docopt


BASEDIR=${PROJECT}/SCanD_project_GMANJ

chmod +x ${BASEDIR}/code/run_group_dtifit_qc.py
chmod +x ${BASEDIR}/code/run_group_enigma_concat.py
chmod +x ${BASEDIR}/code/run_group_qc_index.py

DTIFIT_DIR=${BASEDIR}/data/local/qsiprep/dtifit
ENIGMA_DIR=${BASEDIR}/data/local/qsiprep/enigmaDTI
TBSS_CONTAINER=${BASEDIR}/containers/tbss.simg

singularity exec \
  -B $PROJECT/SCanD_project_GMANJ \
  -B ${BASEDIR}/data/local/qsiprep/enigmaDTI:/enigma_dir \
  -B ${BASEDIR}/data/local/qsiprep/dtifit:/dtifit_dir \
  ${BASEDIR}/containers/tbss.simg \
   /bin/bash

DTIFIT_DIR=/dtifit_dir
OUT_DIR=/enigma_dir

# modify this to the location you cloned the repo to
ENIGMA_DTI_BIDS=$PROJECT/SCanD_project_GMANJ/code

for metric in FA MD RD AD; do
${ENIGMA_DTI_BIDS}/run_group_enigma_concat.py \
  ${OUT_DIR} ${metric} ${OUT_DIR}/group_enigmaDTI_${metric}.csv
${ENIGMA_DTI_BIDS}/run_group_qc_index.py ${OUT_DIR} ${metric}skel
done

${ENIGMA_DTI_BIDS}/run_group_enigma_concat.py --output-nVox \
  ${OUT_DIR} FA ${OUT_DIR}/group_engimaDTI_nvoxels.csv

python ${ENIGMA_DTI_BIDS}/run_group_dtifit_qc.py --debug /dtifit_di

deactivate

cd ${PROJECT}/SCanD_project_GMANJ

exit

