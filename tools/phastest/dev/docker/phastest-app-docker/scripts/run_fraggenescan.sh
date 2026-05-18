#!/bin/bash

function progress_bar() {
    local current=$1
    local total=$2
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

fna_file_basename=$1
fraggenescan_exec=$2
contig_position=$3
log_file=$4

echo "perl $fraggenescan_exec -genome=$fna_file_basename -out=$fna_file_basename -complete=0 -train=complete" >> $log_file
eval "perl $fraggenescan_exec -genome=$fna_file_basename -out=$fna_file_basename -complete=0 -train=complete" >/dev/null 2>&1 &
pid=$!

progress=0
tmpfile="$fna_file_basename\.tmp.0"
total_progress=$(wc -l $contig_position | cut -f1 -d' ')

while [ -e /proc/$pid ]; do
    if [ -e $tmpfile ]; then
        progress=$(grep -c "^>" $tmpfile)
    fi
    progress_bar $progress $total_progress
    sleep 1
done

progress_bar $total_progress $total_progress
echo ""