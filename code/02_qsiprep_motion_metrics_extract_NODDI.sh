module load NiaEnv/2019b python/3.6.8

# Create a directory for virtual environments if it doesn't exist
mkdir ~/.virtualenvs
cd ~/.virtualenvs
virtualenv --system-site-packages ~/.virtualenvs/myenv

# Activate the virtual environment
source ~/.virtualenvs/myenv/bin/activate 

cd $SCRATCH/SCanD_project

python3 code/gen_qsiprep_motion_metrics.py

python3 -m pip install nilearn

python3 code/extract_NODDI_indices.py data/local/derivatives/qsiprep/0.21.4/qsiprep/  data/local/derivatives/qsiprep/0.22.0/amico_noddi/qsirecon-NODDI data/local/derivatives/qsiprep/0.22.0/amico_noddi

