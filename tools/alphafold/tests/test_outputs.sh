#!/usr/bin/env bash

set -e

echo "TEST multimer with per-residue scores"
python gen_extra_outputs.py test-data/multimer_output -p -m

echo "Removing output data..."
rm test-data/multimer_output/plddts.tsv \
   test-data/multimer_output/model_confidence_scores.tsv

echo "PASS"
