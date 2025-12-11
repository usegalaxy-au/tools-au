#!/bin/bash

docker run \
    -v ./test-data:/phastest_inputs \
    -v ./jobs/:/root/phastest-app/JOBS \
    -it \
    phastest -i contig -s contig_test_long.fna
