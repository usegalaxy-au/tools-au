#!/bin/bash

function progress_bar() {
    local current=$1
    local total=100
    local bar_length=20
    local progress
    local progress_percent
    local i

    # If the total is 0, do nothing
    if [ $total -eq 0 ]; then
        return
    fi

    progress=$((current*bar_length/total))
    progress_percent=$((current*100/total))

    printf "\rProgress: ["
    for i in $(seq 1 $progress); do printf "="; done
    for i in $(seq $progress $bar_length); do printf " "; done
    printf "] $progress_percent%%"
}

blast_b_dir=$1
input_file=$2
bac_database_head=$3 # path on cluster head node
bac_database_child=$4 # path on cluster child node
output_file=$5
log_file=$6
diamond_log="diamond.log"

# If the anno_flag == 0, it's possible to have zero non-phage proteins in the phage region.
# $num.faa.non_hit_pro_region will be empty in this case.
if [ ! -s $input_file ]; then
    echo "Input file $input_file does not exist or is empty." >> $log_file
    exit 1
fi

input_basename=`basename $input_file|tr -d "\n"`
blast_out_fmt="6 qseqid stitle pident length mismatch gapopen qstart qend sstart send evalue bitscore"
eval "diamond blastp -d $bac_database_head -f $blast_out_fmt -e 0.0001 -q $input_file -o $output_file --top 10 &> $diamond_log &"
pid=$!

progress=0
while [ -e /proc/$pid ]; do
	most_recent_line=$(tail -n 1 $diamond_log)

    if [[ $most_recent_line == *"Masking reference..."* ]]; then
        progress=10
    elif [[ $most_recent_line == *"Processing query block"* ]]; then
        # Processing query block 1, reference block 1/1, shape 1/2, index chunk 1/4.
        ref_block_total=$(echo $most_recent_line | cut -f7 -d' ' | cut -f2 -d'/')
        shape_total=$(echo $most_recent_line | cut -f9 -d' ' | cut -f2 -d'/')
        index_chunk_total=$(echo $most_recent_line | cut -f12 -d' ' | cut -f2 -d'/' | sed 's/.$//')

        ref_block=$(echo $most_recent_line | cut -f3 -d' ' | cut -f1 -d'/')
        shape=$(echo $most_recent_line | cut -f7 -d' ' | cut -f1 -d'/')
        index_chunk=$(echo $most_recent_line | cut -f11 -d' ' | cut -f1 -d'/')

        echo "$ref_blocks/$ref_block_total $shape/$shape_total $index_chunk/$index_chunk_total" >> test.txt

        current_blocks=$((index_chunk + (shape-1)*index_chunk_total + (ref_block-1)*shape_total*index_chunk_total))
        total_blocks=$((ref_block_total*shape_total*index_chunk_total))

        progress=$((current_blocks*80/total_blocks + 10))

    elif [[ $most_recent_line == *"Computing alignments..."* ]]; then
        progress=90
    fi

	progress_bar $progress
	sleep 1
done

progress_bar 100
printf "\n"