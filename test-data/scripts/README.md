# Scripts

## Overview

Just some handy scripts and snippets for generating test data from full-size files


<br>

## sequence alteration

### obliterate

### mutate


<br>

## fasta

### subset_fasta.py

Writes a section of a fasta to a new file. 
The section is specified by sequence name, then start and end positions along that contig. 

example 1 - pulling a 10kb region (200000 - 210000) from chr1 on input.fasta:

```
python3.9 subset_fasta.py input.fasta chr1 \
        --begin 200000 \
        --end 210000 \
        --outfile out.fasta
```

if --begin is not set, will start at beginning of sequence. 
if --end is not set, will finish at end of sequence. 

example 2 - pulling a specific sequence from input.fasta:

```
python3.9 subset_fasta.py input.fasta 'target_seq_header' \
        --outfile out.fasta
```

The correct sequence is found by matching the supplied query sequence label/header to the headers it finds in the fasta.  If it is not finding the sequence, try the `--flexible` flag which will find the best hit. 

<br>

## fastq

### pull_reads_by_id.py 

Pulls specific reads (by id) from a fastq file and writes to a new file. 

Needs the 

```
grep ERR2935851.277402 ~/reads/bacteria1_SR_1.fastq
@ERR2935851.277402 HWI-C00124:212:C9T75ANXX:4:1108:10861:47108/1

grep ERR2935851.277402 ~/reads/bacteria1_SR_2.fastq
@ERR2935851.277402 HWI-C00124:212:C9T75ANXX:4:1108:10861:47108/2
```