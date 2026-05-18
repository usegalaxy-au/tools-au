#!/bin/bash
# NOTE: This scripts calls parallel blast against the phage virus database.
#       This script used to run the Phage_Finder pipeline.
#       See the original scripts in PHAST (e.g. phage_finder/bin/Phage_Finder.sh)

# NOTE: a phage_finder_info.txt file will be searched before a .ptt file
# .pep is the multifasta protein sequence file
# .ptt is a GenBank .ptt file that has the coordinates and ORF names with annotation
# .con is a file that contains the complete nucleotide sequence of the genome being searched

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

base=`pwd`
job_id=$1
database_head=$2 # Database path on container head node
database_child=$3 # Database path on container child node (hopefully faster)
local_gi_num=$(expr $4 + 0) # Total number of proteins detected in the input sequence
log_file=$5 # Name of the log file

if [ -s $base/$job_id.pep ] # check if .pep file is present
then
    pepfile="$job_id.pep"
elif [ -s $base/$job_id.faa ]
then
    pepfile="$job_id.faa"
else
   echo "Could not file $job_id.pep or $job_id.faa.  Please check to make sure the file is present and contains data" > $log_file.2
   exit 1
fi

if [ -s $base/phage_finder_info.txt ] # check for phage_finder info file and if it has contents
then
    infofile="phage_finder_info.txt"
elif [ -s $base/$job_id.ptt ]
then
      infofile="$job_id.ptt"
else
  echo "Could not find a phage_finder_info.txt file or $job_id.ptt file.  Please make sure one of these files is present and contains data." >> $log_file.2
  exit 1
fi

if [ ! -e $base/ncbi.out ]; then # if BLAST results not present, search
    echo "$base/ncbi.out file does not exist. Performing BLAST search." >> $log_file.2
    
    ## do NCBI BLASTP searches
    echo "" > $base/ncbi.out
    START=$(date +%s)

    eval "which blastp" >> $log_file.2
    echo "Parallel BLASTing $pepfile against the Phage virus DB ..." >> $log_file.2
    echo "blastp -db $database_child -outfmt \"6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore\" -evalue 0.0001 -query $pepfile -out ncbi.out -seg no" >> $log_file.2
    eval "blastp -db $database_child -outfmt \"6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore\" -evalue 0.0001 -query $pepfile -out ncbi.out -seg no" >/dev/null 2>&1 &
    pid=$!
    while [ -e /proc/$pid ]; do
        # gi|00008|ref|NC_000000|	PHAGE_Synech_S_WAM1_NC_031944-gi|100180|ref|YP_009325170.1|	...
        most_recent_line=$(tail -n 1 ncbi.out)
        current_gi=$(echo $most_recent_line | cut -f2 -d'|' | cut -f1 -d' ')
        current_gi=$(expr $current_gi + 0)
        progress_bar $current_gi $local_gi_num
        sleep 1
    done
    END=$(date +%s)
    DIFF=$(( $END - $START ))
    progress_bar $local_gi_num $local_gi_num
    printf "\n"
    echo "Parallel BLASTing $pepfile against the Phage virus DB took $DIFF seconds" >> $log_file.2
else
    echo "$base/ncbi.out already exists. Nothing to do." >> $log_file.2
fi