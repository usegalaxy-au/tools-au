#!/usr/bin/env bash

# You will probably need to create a venv and 'pip install -r alphafold/requirements.txt'
# for the script to be able to read the pickle outputs as they contain jax objects.

set -e

KNRM="\e[0m"
KYEL="\e[93m"
KGRN="\e[92m"
KRED="\e[91m"

EXPECT_OUTPUTS="
test-data/monomer_output/extra/plddts.tsv
test-data/monomer_output/extra/model_confidence_scores.tsv
test-data/monomer_output/extra/ranked_0.pkl
test-data/monomer_output/extra/ranked_1.pkl
test-data/monomer_output/extra/ranked_2.pkl
test-data/monomer_output/extra/ranked_3.pkl
test-data/monomer_output/extra/ranked_4.pkl
test-data/monomer_output/extra/ranked_0.png
test-data/monomer_output/extra/ranked_1.png
test-data/monomer_output/extra/ranked_2.png
test-data/monomer_output/extra/ranked_3.png
test-data/monomer_output/extra/ranked_4.png

test-data/monomer_ptm_output/extra/model_confidence_scores.tsv
test-data/monomer_ptm_output/extra/pae_ranked_0.csv
test-data/monomer_ptm_output/extra/pae_ranked_1.csv
test-data/monomer_ptm_output/extra/pae_ranked_2.csv
test-data/monomer_ptm_output/extra/pae_ranked_3.csv
test-data/monomer_ptm_output/extra/pae_ranked_4.csv
test-data/monomer_ptm_output/extra/ranked_0.pkl
test-data/monomer_ptm_output/extra/ranked_1.pkl
test-data/monomer_ptm_output/extra/ranked_2.pkl
test-data/monomer_ptm_output/extra/ranked_3.pkl
test-data/monomer_ptm_output/extra/ranked_4.pkl
test-data/monomer_ptm_output/extra/ranked_0.png
test-data/monomer_ptm_output/extra/ranked_1.png
test-data/monomer_ptm_output/extra/ranked_2.png
test-data/monomer_ptm_output/extra/ranked_3.png
test-data/monomer_ptm_output/extra/ranked_4.png

test-data/multimer_output/extra/plddts.tsv
test-data/multimer_output/extra/model_confidence_scores.tsv
test-data/multimer_output/extra/pae_ranked_0.csv
test-data/multimer_output/extra/pae_ranked_1.csv
test-data/multimer_output/extra/pae_ranked_2.csv
test-data/multimer_output/extra/pae_ranked_3.csv
test-data/multimer_output/extra/pae_ranked_4.csv
test-data/multimer_output/extra/ranked_0.pkl
test-data/multimer_output/extra/ranked_1.pkl
test-data/multimer_output/extra/ranked_2.pkl
test-data/multimer_output/extra/ranked_3.pkl
test-data/multimer_output/extra/ranked_4.pkl
test-data/multimer_output/extra/ranked_0.png
test-data/multimer_output/extra/ranked_1.png
test-data/multimer_output/extra/ranked_2.png
test-data/multimer_output/extra/ranked_3.png
test-data/multimer_output/extra/ranked_4.png"

# Check PWD
if [[ ! "$PWD" == *"/tests" ]]; then
  cd ..
fi

printf "${KYEL}TEST monomer output${KNRM}\n"
python scripts/outputs.py test-data/monomer_output -p --pkl --plot

echo ""
printf "${KYEL}TEST monomer_ptm output${KNRM}\n"
python scripts/outputs.py test-data/monomer_ptm_output -p --pkl --plot --pae

echo ""
printf "${KYEL}TEST multimer output${KNRM}\n"
python scripts/outputs.py test-data/multimer_output -p -m --pkl --plot --pae

echo ""
printf "${KYEL}TEST monomer_ptm outputs individually...${KNRM}\n"
python scripts/outputs.py test-data/monomer_ptm_output -p
python scripts/outputs.py test-data/monomer_ptm_output --pkl
python scripts/outputs.py test-data/monomer_ptm_output --plot
python scripts/outputs.py test-data/monomer_ptm_output --pae

for path in $EXPECT_OUTPUTS; do
  if [ ! -f $path ]; then
    printf "${KRED}FAIL: output file '$path' not found${KNRM}\n"
    exit 1
  fi
done

if [[ "$@" != *"--keep"* ]]; then
  echo ""
  printf "${KGRN}Removing output data...\n"
  rm -rf \
    test-data/*mer*output/extra
else
    printf "\n${KGRN}Output files created:
    test-data/*_output/extra/model_confidence_scores.tsv
    test-data/*_output/extra/plddts.tsv
    test-data/*_output/extra/relax_metrics_ranked.json
    test-data/*_output/extra/ranked_*.pkl
    test-data/*_output/extra/ranked_*.png\n"
fi

printf "\nPASS\n\n${KNRM}"
