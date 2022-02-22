#!/usr/bin/env bash

# Enumerate kmers with Jellyfish
echo "Running Jellyfish count..."
jellyfish count -m 21 -t 4 -s 1M -o 1_counts.jf -C reads.fasta
jellyfish histo 1_counts.jf > 1_kmer_k21.hist

# Extract genomic kmers from jellyfish count
echo "Calculating lower and upper kmer count cutoffs..."
L=$(smudgeplot.py cutoff 1_kmer_k21.hist L)
U=$(smudgeplot.py cutoff 1_kmer_k21.hist U)

# Uncomment to hard code cutoffs
#L=5
#U=20
echo "LOWER = $L"
echo "UPPER = $U"

echo "Dumping kmers within range..."
jellyfish dump -c -L $L -U $U 1_counts.jf > 2_dump.jf

echo "Running smudgeplot hetkmers"
smudgeplot.py hetkmers -o 2_kmer_pairs 2_dump.jf

echo "Generating smudgeplot..."
smudgeplot.py plot 2_kmer_pairs_coverages.tsv -o my_genome
