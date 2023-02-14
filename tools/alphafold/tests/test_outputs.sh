#!/usr/bin/env bash

# You will probably need to create a venv and 'pip install -r alphafold/requirements.txt'
# for the script to be able to read the pickle outputs as they contain jax objects.

set -e

EXPECT_OUTPUTS="
test-data/monomer_output/plddts.tsv
test-data/monomer_output/model_confidence_scores.tsv
test-data/monomer_output/model_1.pkl
test-data/monomer_output/model_2.pkl
test-data/monomer_output/model_3.pkl
test-data/monomer_output/model_4.pkl
test-data/monomer_output/model_5.pkl
test-data/multimer_output/plddts.tsv
test-data/multimer_output/model_confidence_scores.tsv
test-data/multimer_output/model_1.pkl
test-data/multimer_output/model_2.pkl
test-data/multimer_output/model_3.pkl
test-data/multimer_output/model_4.pkl
test-data/multimer_output/model_5.pkl"

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

echo ""
echo "Removing output data..."
rm -f \
   test-data/*mer_output/plddts.tsv \
   test-data/*mer_output/model_confidence_scores.tsv \
   test-data/*mer_output/model_*.pkl

echo ""
echo "PASS"
