# AlphaFold - for developers

The AlphaFold tool comprises several components:

- Wrapper `alphafold.xml` and associated `macro*.xml` files.
- Input FASTA validation `validate_fasta.py`
- Output file generation `outputs.py`
- Docker image - see `docker/` for building (hosted at hub.docker.com/neoformit/alphafold)
- AlphaFold mock for testing `fetch_test_data.sh`
- Test script for `outputs.py` - `tests/test_outputs.sh`
- Output data from different model presets for mocking - `test-data/*mer*_output/`
- HTML visualization output - `alphafold.html`


## Planemo testing

Add the following line to Planemo's Galaxy venv activation script (should be something like `~/.planemo/gx_venv_3/bin/activate`)

```sh
export PLANEMO_TEST=1
```

When you `planemo test` the wrapper should use the mock AlphaFold run, which copies AlphaFold outputs from `test-data/*mer*_output/` directories.


## Generating additional outputs

To run the outputs.py file you will need to install some dependencies (a virtual environment is highly recommended). Note if you want to run this with `planemo serve`, you will need to run the following in the planemo-galaxy's virtual environment (the path to the env being used is printed to stdout when you run the tool):

```sh
pip install -r scripts/requirements.txt
```

The `./scripts/outputs.py` script is used to generate additional outputs from an AF2 run. This script is complex because it must handle all different output variations (monomer, multimer, N models, etc.). The test script `tests/test_outputs.sh` runs a basic end-to-end test with the sample outputs available in `test-data/`. Each of these directories is a complete output directory for an AF2 run, for each of the three model presets:

```
test-data
├── monomer_output/
├── monomer_ptm_output/
└── multimer_output/
```

`tests/test_outputs.sh` generates output files for each of these output directories and asserts that all expected outputs have been created:

```bash
# From the alphafold root dir
tests/test_outputs.sh

# Keep the test outputs to manually check them
tests/test_outputs.sh --keep
```

You can also run `./scripts/outputs.py` as a standalone script against any AF2 output directory to replicate the Galaxy tool's addition outputs:

```
ubuntu:/dev/tools-au/tools/alphafold$ python scripts/outputs.py -h
usage: outputs.py [-h] [-s] [--pkl] [--pae] [--plot] [--plot-msa] workdir

positional arguments:
  workdir               alphafold output directory

options:
  -h, --help            show this help message and exit
  -s, --confidence-scores
                        output per-residue confidence scores (pLDDTs)
  --pkl                 rename model pkl outputs with rank order
  --pae                 extract PAE from pkl files to CSV format
  --plot                Plot pLDDT and PAE for each model
  --plot-msa            Plot multiple-sequence alignment coverage as a heatmap
```

```sh
# Additional outputs will be written to /my/alphafold/output/dir/extra/
python scripts/outputs.py /my/alphafold/output/dir/ --pr-scores --pae --pkl --plot --plot-msa
```
