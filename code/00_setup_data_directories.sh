## hold many of the scripts needed to set-up the repo for the first time..
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

## i.e. makes folders and links to software in the arisvoin (CAMH) lab space
mkdir -p ${SCRIPT_DIR}/../containers
mkdir -p ${SCRIPT_DIR}/../data
mkdir -p ${SCRIPT_DIR}/../data/local
mkdir -p ${SCRIPT_DIR}/../data/share
mkdir -p ${SCRIPT_DIR}/../templates
mkdir -p ${SCRIPT_DIR}/../logs


