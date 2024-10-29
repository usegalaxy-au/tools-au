# Patching the MMCIF database

Due to the PDB MMCIF databases being out-of-sync with other AlphaFold
reference databases, the following error has been seen in AlphaFold2:

```
FileNotFoundError: [Errno 2] No such file or directory: '/alphafold_dbs/pdb_mmcif/mmcif_files/XXXX.cif'
```

`patch_mmcif.py` is a standalone script that cross-references your AlphaFold2 databases and attempts to patch missing .cif files from the RCSB database.

## Usage

- Copy the script to your server
- Ensure that `python >= 3.8` is available
- `pip install requests`
- Run `patch_mmcif.py` from any directory

You must specify the path to your databases when you run the script.

```
$ python patch_mmcif.py --help
usage: patch_mmcif.py [-h] [-i ID] [--write-db] [--log] db_path

Patch missing MMCIF files in your AlphaFold DB. This script will sniff your databases for
missing .cif files and download them from the RCSB PDB. If the --write-db flag is set,
the files will be copied directly to the AlphaFold database mmcif_files directory.

Example usage:

  # Write mmcif files locally (don't write to AF databases)
  python patch_mmcif.py /my/alphafold/db/

  # Patch all missing files in the database and log changes
  python patch_mmcif.py /my/alphafold/db/ --write-db --log

  # Patch a single missing file
  python patch_mmcif.py /my/alphafold/db/ -i 4ri6 --write-db

positional arguments:
  db_path         Path to your AlphaFold database root

options:
  -h, --help      show this help message and exit
  -i ID, --id ID  4-char PDB ID for a .cif file to patch (non-case-sensitive) (if
                  excluded, will attempt to sniff the database and patch all missing
                  files)
  --write-db      Copy the files directly to the AlphaFold database mmcif_files directory.
                  If this option is omitted, files will be written locally to
                  ./mmcif_files/*.cif and must then be manually copied to the database
                  pdb_mmcif/mmcif_files directory. Omit this option to prevent the script
                  from writing to your database.
  --log           Write patched PDB files/IDs to ./logs/. This is useful for keeping track
                  of which files were patched. The following files will be written:
                  [required_ids.log, existing_ids.log, missing_ids.log]. Patched MMCIF
                  files will be copied to ./logs/mmcif_patches/.

```

## How does it work

The script enumerates unique PDB identifiers in the database file `pdb70/pdb70_clu.tsv`, which looks like this:

```
3TC3_B  3TC3_B
3TC3_B  4GLE_A
3TC3_B  3TC3_A
4RI6_A  4RI6_A
4RI6_A  4RI6_B
4RI6_A  4RI7_A
4RI7_A  4RI7_B
```

The identifiers here are what is expected to be in the `mmcif_files` directory at runtime.
The script extracts a unique list of identifiers from this file, then subtracts those that are already present in the `pdb_mmcif/mmcif_files/` directory to get a list of missing files. It then downloads these from https://files.rcsb.org/download/ and writes them to the appropriate location.

## Tests

Run unit tests for `patch_mmcif.py` from this directory:

```sh
python -m unittest tests/test_patch_all.py
```
