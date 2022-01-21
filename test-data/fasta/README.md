# FASTA files

### Assemblies

These synthetic assemblies were produced from the first 100kbp of the E. coli
chromosome taken from NCBI
(NZ_CP090611.1 Escherichia coli isolate DCE7 chromosome, complete genome)

They were produced using the `./test-data/scripts/obliterate` tool as follows:

```sh
# Create synthetic_shortread_assembly_ecoli.fasta
obliterate --n50 2000 --min-gap 100 --max-gap 500 ecoli_1_100kbp.fasta

# Create synthetic_longread_assembly_ecoli.fasta
obliterate --n50 20000 --min-gap 500 --max-gap 1500 ecoli_1_100kbp.fasta
```

Currently used by:
- QuickMerge

---
