#!/bin/bash

IMAGE="phastest"
INPUT_FILE="test.fna"
INPUT_TYPE="seq"
DEEP_MODE="lite"
DATA_DIR="./test-data"

while getopts "lcd" opt; do
    case $opt in
        l) INPUT_FILE="test_long.fna" ;;
        c) INPUT_TYPE="contig" ;;
        d) DEEP_MODE="deep" ;;
        *) echo "Invalid option"; exit 1 ;;
    esac
done

shift $((OPTIND - 1))

if [[ $1 != "" ]]; then
    INPUT_FILE=$(basename "$1")
    DATA_DIR=$(realpath "$(dirname "$1")")
    if [[ "$INPUT_TYPE" == "seq" ]]; then
        INPUT_MODE="fasta"
    else
        INPUT_MODE="contig"
    fi
else
    if [[ "$INPUT_TYPE" == "seq" ]]; then
        INPUT_FILE="seq_$INPUT_FILE"
        INPUT_MODE="fasta"
    else
        INPUT_FILE="contig_$INPUT_FILE"
        INPUT_MODE="contig"
    fi
fi

echo "Using image: $IMAGE"
echo "Input mode:  $INPUT_MODE"
echo "Input file:  $INPUT_FILE"
echo "Data dir:    $DATA_DIR"


docker run \
    -v "$DATA_DIR:/phastest_inputs" \
    -v ./jobs/:/root/phastest-app/JOBS \
    -v ./refdata/DB:/root/phastest-app/DB \
    $IMAGE -i $INPUT_MODE -s $INPUT_FILE -m $DEEP_MODE --yes
