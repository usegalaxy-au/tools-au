#
# Pull test data from github for dummy alphafold run
# Pass single param MODEL_PRESET
#
# If test-data folder is available (i.e. testing from github repo, not toolshed
# clone) it will copy from there. Otherwise it will download from github.
#
# If you intend to use this for planemo testing, you will most likely need to
# pip-install the following packages into planemo's virtualenv (echo'd below):
#   - matplotlib
#   - jax
#   - jaxlib
#
# These are installed in the alphafold container, but planemo seems to ignore
# the docker requirement.
#


if [ $# -ne 1 ]; then
    echo "Usage: $0 [monomer|monomer_ptm|multimer]"
    exit 1
fi

echo "Using Python interpreter: $(which python)"

MODEL_PRESET=$1
SCRIPTS_DIRECTORY="$(dirname $0)"
TOOL_DIRECTORY="$(dirname $SCRIPTS_DIRECTORY)"
REMOTE_URL=https://github.com/usegalaxy-au/tools-au/archive/refs/heads/master.zip
ZIPFILE=master.zip
ZIPFILE_ROOT=tools-au-master
REPO_PATH=tools/alphafold/test-data/${MODEL_PRESET}_output
OUT=output/alphafold

mkdir -p "$(dirname $OUT)"

test_data_dir="${TOOL_DIRECTORY}/test-data/${MODEL_PRESET}_output"

if [ -d $test_data_dir ]; then
    echo "Copying mock outputs from local repo: ${test_data_dir}..."
    cp -R "$test_data_dir" $OUT
else
    echo "No test data available at $test_data_dir"
    exit 0
fi

echo Done
