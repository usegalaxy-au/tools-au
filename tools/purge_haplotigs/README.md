# Purge Haplotigs
Pipeline to help with curating heterozygous diploid genome assemblies from third-gen long-read sequencing.

# Dependencies
- Bash
- BEDTools (tested with v2.26.0)
- SAMTools (tested with v1.7)
- Minimap2 (tested with v2.11/v2.12, https://github.com/lh3/minimap2)
- Perl (with core modules: FindBin, Getopt::Long, Time::Piece, threads, Thread::Semaphore, Thread::Queue, List::Util)
- Rscript (with ggplot2)

# Installation
Currently only tested on Ubuntu, there is a Detailed manual installation example for Ubuntu 16.04 LTS in the wiki.

# Easy Installation using bioconda
- Create a conda environment called 'purge_haplotigs' and install Purge Haplotigs in it:

```
conda create -n purge_haplotigs -c conda-forge -c bioconda purge_haplotigs

```
- Activate your new conda env and test the pipeline

```
conda activate purge_haplotigs
purge_haplotigs test

```

The latest version of purge_haplotigs is 1.1.2 and can be found on [conda](https://anaconda.org/bioconda/purge_haplotigs) 

See [official documentation](https://bitbucket.org/mroachawri/purge_haplotigs/src/master/) for more details.
