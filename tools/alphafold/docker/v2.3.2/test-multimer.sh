#!/usr/bin/env bash

set -e

# Use this script for a CLI test of AF2 container.

ALPHAFOLD_DB_DIR=/mnt/alphafold_db/alphafold_db/2.3
WDIR=./working
TODAY=`date +"%Y-%m-%d"`

mkdir -p $WDIR

echo ">NP_000549.1 hemoglobin subunit alpha [Homo sapiens]
MVLSPADKTNVKAAWGKVGAHAGEYGAEALERMFLSFPTTKTYFPHFDLSHGSAQVKGHGKKVADALTNA
VAHVDDMPNALSALSDLHAHKLRVDPVNFKLLSHCLLVTLAAHLPAEFTPAVHASLDKFLASVSTVLTSK
YR
>NP_000509.1 hemoglobin subunit beta [Homo sapiens]
MVHLTPEEKSAVTALWGKVNVDEVGGEALGRLLVVYPWTQRFFESFGDLSTPDAVMGNPKVKAHGKKVLG
AFSDGLAHLDNLKGTFATLSELHCDKLHVDPENFRLLGNVLVCVLAHHFGKEFTPPVQAAYQKVVAGVAN
ALAHKYH
" > $WDIR/multimer.fasta

sudo docker run --rm -v $ALPHAFOLD_DB_DIR:/data -v $WDIR:/app/alphafold/working neoformit/alphafold:v2.3.2_dev \
    python /app/alphafold/run_alphafold.py \
        --fasta_paths working/multimer.fasta \
        --output_dir /working/output_multimer \
        --data_dir /data \
        --model_preset=multimer \
\
        `# Reduced dbs` \
        --db_preset=reduced_dbs \
        --uniref90_database_path   /data/uniref90/uniref90.fasta \
        --mgnify_database_path     /data/mgnify/mgy_clusters_2022_05.fa \
        --template_mmcif_dir       /data/pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path       /data/pdb_mmcif/obsolete.dat \
        --small_bfd_database_path  /data/small_bfd/bfd-first_non_consensus_sequences.fasta \
\
        `# multimer dbs` \
        --pdb_seqres_database_path=/data/pdb_seqres/pdb_seqres.txt \
        --uniprot_database_path=/data/uniprot/uniprot.fasta \
        --num_multimer_predictions_per_model=1 \
\
        --use_gpu_relax=True \
        --max_template_date=$TODAY

echo "Test run complete"
