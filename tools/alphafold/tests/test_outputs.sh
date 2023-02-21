#!/usr/bin/env bash

# You will probably need to create a venv and 'pip install -r alphafold/requirements.txt'
# for the script to be able to read the pickle outputs as they contain jax objects.

set -e

EXPECT_OUTPUTS="
test-data/monomer_output/extra/plddts.tsv
test-data/monomer_output/extra/model_confidence_scores.tsv
test-data/monomer_output/extra/model_1.pkl
test-data/monomer_output/extra/model_2.pkl
test-data/monomer_output/extra/model_3.pkl
test-data/monomer_output/extra/model_4.pkl
test-data/monomer_output/extra/model_5.pkl
test-data/multimer_output/extra/plddts.tsv
test-data/multimer_output/extra/model_confidence_scores.tsv
test-data/multimer_output/extra/model_1.pkl
test-data/multimer_output/extra/model_2.pkl
test-data/multimer_output/extra/model_3.pkl
test-data/multimer_output/extra/model_4.pkl
test-data/multimer_output/extra/model_5.pkl"

echo "TEST monomer output with per-residue scores"
python outputs.py test-data/monomer_output -p --model-pkl

echo ""
echo "TEST multimer output with per-residue scores"
python outputs.py test-data/multimer_output -p -m --model-pkl

for path in $EXPECT_OUTPUTS; do
  if [ ! -f $path ]; then
    echo "FAIL: output file '$path' not found"
    exit 1
  fi
done

if [[ "$@" != *"--keep"* ]]; then
  echo ""
  echo "Removing output data..."
  rm -rf \
    test-data/*mer_output/extra \
else
    echo "Output files created:
    test-data/*mer_output/extra/plddts.tsv
    test-data/*mer_output/extra/model_confidence_scores.tsv
    test-data/*mer_output/extra/model_*.pkl"
fi

echo ""
echo "PASS"
