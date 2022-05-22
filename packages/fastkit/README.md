# FastKit

Fastkit is primarily written to perform routine/repetitive operations on
FASTA and FASTQ files, most notably formatting. Its purpose is
pre-processing of files for use in other bioinformatics tools.

FastKit should seek to abstract established libraries (such as Biopython,
  SeqTK, FASTX-toolkit, etc) rather than re-invent the wheel!

Outputs should always be written to stdout so that the consumer can easily
change file names.

---

### Example usage

```sh
fastkit format input.raw.fasta --strip-header-space > input.fasta
```
