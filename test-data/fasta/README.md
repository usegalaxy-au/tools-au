# FASTA files





bacteria1

- bacillus subtilis genome
- approx 4gbp 
- have short (illumina) and long (nanopore) reads
- from this paper: https://academic.oup.com/gigascience/article/8/5/giz043/5486468#136473928


basteria1 slices

- files
    - bacteria1_SR_assembly.fasta
    - bacteria1_SR_assembly_slice.fasta
    - bacteria1_SR_alignments_slice.fasta
    - bacteria1_SR_reads_slice.fasta (coming soon)
    
    - bacteria1_LR_assembly.fasta
    - bacteria1_LR_assembly_slice.fasta
    - bacteria1_LR_alignments_slice.fasta
    - bacteria1_LR_reads_slice.fasta (coming soon)

- sections taken from the SR (short read) and LR (long read) assemblies
- section size = 100kb
- the sections are equivalent (corresponding) in both assemblies (same part of genome)
- for each slice there are also read alignments to that slice (same tech - SR alignments for SR assembly slice)
- SR_assembly
    - header: NODE_1_length_768453_cov_10.805209
    - start: 100000
    - stop: 200000
- LR_assembly
    - header: contig_16
    - start: 402307
    - stop: 502053
