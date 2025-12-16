#!/bin/bash

INPUT_FILE="test.fna"
IMAGE="phastest"
INPUT_TYPE="seq"

while getopts "loco" opt; do
    case $opt in
        l) INPUT_FILE="test_long.fna" ;;
        o) IMAGE="phastest-original" ;;
        c) INPUT_TYPE="contig" ;;
        *) echo "Invalid option"; exit 1 ;;
    esac
done

if [ "$INPUT_TYPE" == "seq" ]; then
    INPUT_FILE="seq_$INPUT_FILE"
    INPUT_MODE="fasta"
else
    INPUT_FILE="contig_$INPUT_FILE"
    INPUT_MODE="contig"
fi

echo "Using image:      $IMAGE"
echo "Input mode:       $INPUT_MODE"
echo "Input file: $INPUT_FILE"


docker run \
    -v ./test-data:/phastest_inputs \
    -v ./jobs/:/root/phastest-app/JOBS \
    -v ./refdata/DB:/root/phastest-app/DB \
    $IMAGE phastest -i $INPUT_MODE -s $INPUT_FILE
