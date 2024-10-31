#!/usr/bin/env bash

# Use this script for a CLI test of AF2 container.
# Benchmarked at 0:42 for 1 model

set -e

ALPHAFOLD_DB_DIR=/mnt/alphafold_db/alphafold_db
WDIR=./working
TODAY=`date +"%Y-%m-%d"`

mkdir -p $WDIR

echo ">UPI0015CE2E61 status=active
DGKILADKVSDKLEQTATLTGLDYGRFTRSMLLSQGQFAAFLNAKPSDRAELLEELTGTE
IYGQISAMVYEQHKAARHALEKFEAQAAGIVLLTEAQQ
" > $WDIR/monomer.fasta

sudo docker run --rm --gpus all -v $ALPHAFOLD_DB_DIR:/data -v $WDIR:/app/alphafold/working neoformit/alphafold:v2.3.2_dev \
    python /app/alphafold/run_alphafold.py \
        --fasta_paths working/monomer.fasta \
        --output_dir /working/output_monomer \
        --data_dir /data \
        --model_preset=monomer \
\
        `# Reduced dbs` \
        --db_preset=reduced_dbs \
        --uniref90_database_path   /data/uniref90/uniref90.fasta \
        --mgnify_database_path     /data/mgnify/mgy_clusters_2022_05.fa \
        --template_mmcif_dir       /data/pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path       /data/pdb_mmcif/obsolete.dat \
        --small_bfd_database_path  /data/small_bfd/bfd-first_non_consensus_sequences.fasta \
\
        `# monomer dbs` \
        --pdb70_database_path /data/pdb70/pdb70 \
\
        --use_gpu_relax=True \
        --max_template_date=$TODAY \
        --output_models=1

echo "Test run complete"
