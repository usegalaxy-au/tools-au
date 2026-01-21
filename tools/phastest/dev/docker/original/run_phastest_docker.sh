#!/bin/bash

#Welcome to PHASTEST!

#Run PHASTEST with these parameters?
#Input format: fasta
#Job ID: seq_test
#Annotation Mode: lite

#Options:
#  Skip confirmation prompt (--yes): No
#  Silence PHASTEST output messages (--silent): No
#  Annotate phage region only (--phage-only): No

#Continue PHASTEST with these parameters? (Y/N) Y


docker compose run phastest -i fasta -s seq_test.fna
