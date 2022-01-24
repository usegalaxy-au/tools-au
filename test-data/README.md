# Test data

A collection of test data files that can be re-used for tool development and testing.

**TODO**
- gbk
- gtf / gff3
- gene sequences fasta 
- protein sequences fasta 
- proteome fasta 
- 


## Contents

- [Requirements](#requirements)
- [Test Data](#test-data)
- [Methods to Subset Data](#methods-to-subset-data)

<br>

## Requirements
- Galaxy test data max file size 500KB 
- Repo max file size 100MB (as of Sept 2020)
- Integrity: ensure that reads etc are paired and overlapping (if required)
- Docs - add an entry to the folder's `README.md` file to describe the file content



<br>

## Test Data 

### Bacteria1

*Sample Details*
- Bacillus subtilis genome
- Approx 4gbp 
- Short (illumina) and long (nanopore) reads were available
- Short / long reads were used to assemble the genome from each individual seq tech
- Equivalent corresponding slice (100kb) of asssemblies was taken.
- Files were created for use in this repo. All are based on the assembly slice. 
    - LR assembly slice: `contig_16:402307-502053` from LR assembly
    - SR assembly slice: `NODE_1_length_768453_cov_10.805209:100000-200000` from SR assembly
    - sam slice: reads were aligned to full assembly, then sam slice taken as above
    - reads slice: reads appearing in the sam slice were extracted to create a subset fastq 
- Paper: https://academic.oup.com/gigascience/article/8/5/giz043/5486468#136473928
- Reference genome & other data: https://www.ncbi.nlm.nih.gov/assembly/GCF_006094475.1

*Reference Files*
- Genome: `reference_genomes/bacteria1_reference_genome.fasta`
- Transcriptome: `transcriptome/bacteria1_transcriptome.fna`
- Proteome: `proteome/bacteria1_proteome.fna`
- Annotations: 
    - `bacteria1_features.gff`
    - `bacteria1_features.gtf`
    - `bacteria1_genbank.gbff`
- Variant calls: `variants/bacteria1_variants.vcf` (generated with SRs)
- SV calls: `variants/bacteria1_SVs.vcf` (generated with LRs)

*SR Files*
- full assembly: `fasta/bacteria1_SR_full_assembly.fasta`
- assembly slice: `fasta/bacteria1_SR_assembly_slice.fasta`
- sam slice: `sam_bam/bacteria1_SR_alignments_slice.sam`
- reads slice: `fastq/bacteria1_SR_reads_slice_1/2.sam`

*LR Files*
- full assembly: `fasta/bacteria1_LR_full_assembly.fasta`
- assembly slice: `fasta/bacteria1_LR_assembly_slice.fasta`
- sam slice: `sam_bam/bacteria1_LR_alignments_slice.sam`
- reads slice: `fastq/bacteria1_LR_reads_slice.sam`

<br>

## Methods to Subset Data


### Fasta

```
scripts subset_fasta.py
```

### Fastq

```
scripts pull_reads_by_id.py
```

### SAM / BAM

Read the [samtools](http://www.htslib.org/doc/samtools.html) documentation. Samtools does all the manipulation you will most likely ever need for sam/bam files. 

Pull the sam entries for reads which overlap a genome section (slice)

```
samtools view -h alignments.sam chr1:10000-20000
```

Pull sam entries which are aligned on reverse strand

```
samtools view -f 0x10
# or
samtools view -f 16
```

Pull each read id from a sam file

```
cut -f1 alignments.sam | grep -v ^@ > read_ids.txt
```
