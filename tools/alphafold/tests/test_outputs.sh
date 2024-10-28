#!/usr/bin/env bash

# You will probably need to create a venv and 'pip install -r alphafold/requirements.txt'
# for the script to be able to read the pickle outputs as they contain jax objects.

set -e

KNRM="\e[0m"
KYEL="\e[93m"
KGRN="\e[92m"
KRED="\e[91m"

EXPECT_OUTPUTS="
test-data/monomer_output/extra/alphafold.html
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
test-data/monomer_output/extra/msa_coverage.png

test-data/monomer_ptm_output/extra/alphafold.html
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
test-data/monomer_ptm_output/extra/msa_coverage.png

test-data/multimer_output/extra/alphafold.html
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
test-data/multimer_output/extra/ranked_4.png
test-data/multimer_output/extra/msa_coverage.png"

if [[ `pip freeze | grep jax` = '' ]]; then
  echo "JAX is required to open AF2 pkl files. Please see ./scripts/pip_install_jax.sh to install."
  exit 1
fi

# Check PWD
if [[ "$PWD" == *"/tests" ]]; then
  cd ..
fi

printf "${KYEL}TEST monomer output${KNRM}\n"
python scripts/outputs.py test-data/monomer_output --confidence-scores --pkl --plot --plot-msa

echo ""
printf "${KYEL}TEST monomer_ptm output${KNRM}\n"
python scripts/outputs.py test-data/monomer_ptm_output --confidence-scores --pkl --plot --pae --plot-msa

echo ""
printf "${KYEL}TEST multimer output${KNRM}\n"
python scripts/outputs.py test-data/multimer_output --confidence-scores --pkl --plot --pae --plot-msa


# For testing generation of individual outputs:
# echo ""
# MODEL_PRESET="monomer_ptm"
# printf "${KYEL}TEST $MODEL_PRESET outputs individually...${KNRM}\n"
# python scripts/outputs.py test-data/${MODEL_PRESET}_output -p
# python scripts/outputs.py test-data/${MODEL_PRESET}_output --pkl
# python scripts/outputs.py test-data/${MODEL_PRESET}_output --plot
# python scripts/outputs.py test-data/${MODEL_PRESET}_output --pae
# python scripts/outputs.py test-data/${MODEL_PRESET}_output --plot-msa

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
    test-data/*_output/extra/ranked_*.png
    (and others)\n"
fi

printf "\nPASS\n\n${KNRM}"
