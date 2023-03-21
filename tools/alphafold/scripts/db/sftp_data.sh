#!/usr/bin/bash

# Run with:
# --reduced for reduced_dbs only
# --multimer to include multimer dbs

set -e

SRC_USER=ubuntu
SRC_HOST=20.70.170.176  # ssh auth must already be established
SRC_DB_ROOT=/data/alphafold_databases
DEST_DB_ROOT=/data/alphafold_databases

function download_db() {
  if [ ! -f "$1" ]; then
    echo "Downloading $1..."
    sftp "${SRC_USER}@${SRC_HOST}:${SRC_DB_ROOT}/$1" "$1"
  else
    echo "Skipping $1: local copy exists"
  fi

  echo "Extracting downloaded archive..."
  tar xzf "$1"
}

cd $DEST_DB_ROOT

# Required for all runs
# -----------------------------------------------------------------------------
# Params - 3.5 GB (download: 3.5 GB)
download_db params.tar.gz

# Mgnify - 64 GB (download: 32.9 GB)
download_db mgnify.tar.gz

# PDB MMCIF - 206 GB (download: 46 GB)
download_db pdb_mmcif.tar.gz

# uniref90 - 58 GB (download: 29.7 GB)
download_db uniref90.tar.gz

# PDB70 - 56 GB (download: 19.5 GB)
download_db pdb70.tar.gz

if [[ --reduced in $@ ]]; then
  # Required for reduced_dbs
  # ---------------------------------------------------------------------------
  # Small BFD - 17 GB (download: 9.6 GB)
  download_db small_bfd.tar.gz
else
  # Required for full_dbs
  # ---------------------------------------------------------------------------
  # Big BFD - 1.7 TB (download: 271.6 GB)
  download_db bfd.tar.gz

  # Uniclust30 - 86 GB (download: 24.9 GB)
  download_db uniclust30.tar.gz
fi

if [[ --multimer in $@ ]]; then
  # Required for multimer
  # ---------------------------------------------------------------------------
  # PDB seqres - 200 MB (download: 200 MB)
  download_db pdb_seqres.tar.gz

  # Uniprot - 98.3 GB (download: 49 GB)
  download_db uniprot.tar.gz
fi

echo "Download complete"
