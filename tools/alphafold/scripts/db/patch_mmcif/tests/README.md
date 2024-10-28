# Patching the MMCIF database

Due to the PDB MMCIF databases being out-of-sync with other AlphaFold
reference databases, the following error has been seen in AlphaFold2:

```
FileNotFoundError: [Errno 2] No such file or directory: '/alphafold_dbs/pdb_mmcif/mmcif_files/XXXX.cif'
```

The `patch_mmcif.py` script cross-references your AlphaFold2 databases and attempts to patch missing .cif files from the RCSB database.

```
$ python patch_mmcif.py -h
usage: patch_mmcif.py [-h] [--log] db_path mmcif_id

Download and place MMCIF files into AlphaFold DB.

positional arguments:
  db_path     Path to your AlphaFold database root
  mmcif_id    4-char PDB ID for your missing .cif file (if excluded, will attempt to sniff all missing files in your database)

options:
  -h, --help  show this help message and exit
  --log       Write patched PDB IDs to log files in $PWD
```

Run unit tests for patch_mmcif.py:

```sh
python -m unittest tests/test_patch_all.py
```
