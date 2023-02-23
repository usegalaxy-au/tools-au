*A Galaxy Wrapper of IPA HiFi Genome Assembler*

**Description**

This repo contains the implementation of the IPA HiFi Genome Assembler. It's currently implemented as a Snakemake workflow (workflow/ipa.snakefile) and runs the following stages:

1. Building the SeqDB and SeedDB from the input reads.
2. Overlapping using the Pancake overlapper.
3. Phasing the overlaps using the Nighthawk phasing tool.
4. Filtering the overlaps using Falconc m4Filt.
5. Contig construction using Falcon's ovlp_to_graph and graph_to_contig tools.
6. Read tracking for read-to-contig assignment.
7. Polishing using Racon.

For more info: https://github.com/PacificBiosciences/pbipa and https://github.com/PacificBiosciences/pbbioconda/wiki/Improved-Phased-Assembler

*test-data*


The test data can be downloaded from ([bam](https://downloads.pacbcloud.com/public/dataset/2021-11-Microbial-96plex/demultiplexed-reads/m64004_210929_143746.bc2046.bam)) or select one of the bam files [here](https://downloads.pacbcloud.com/public/dataset/2021-11-Microbial-96plex/demultiplexed-reads/) or a small ccs bam (85MB) bam file [here](https://downloads.pacbcloud.com/public/dataset/ISMB_workshop/isoseq3/alz.ccs.bam)

*planemo test*

1. download the m64004_210929_143746.bc2046.bam file into test-data folder
2. create a softlink (test.bam) pointing to m64004_210929_143746.bc2046.bam

3. run planemo test (i.e. planemo test --galaxy_root=/path/to/your/galaxy/folder ipa.xml)
or 
3. run planemo test  --update_test_data (i.e. planemo test --galaxy_root=/path/to/your/galaxy/folder ipa.xml) to update the test data
or
