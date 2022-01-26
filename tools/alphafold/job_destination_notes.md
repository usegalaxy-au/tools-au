

## JOB DESTINATION

Alphafold needs a custom singularity job destination to run. 
The destination needs to be configured for singularity, and some
extra singularity params need to be set as seen below.

specify job runner
for example, a local runner

```
<plugin id="alphafold_runner" type="runner" load="galaxy.jobs.runners.local:LocalJobRunner"/>
```

customise job destination with singularity settings. 
add your own params depending on runner setup! 

```
<destination id="alphafold" runner="alphafold_runner">
    <param id="dependency_resolution">'none'</param>
    <param id="singularity_enabled">true</param>
    <param id="singularity_run_extra_arguments">--nv</param>
    <param id="singularity_volumes">"$job_directory:ro,$tool_directory:ro,$job_directory/outputs:rw,$working_directory:rw,/data/alphafold_databases:/data:ro"</param>
</destination>
```

<br>

## REFERENCE DATA

Alphafold needs reference data to run. The wrapper expects this data to be present at `/data/`. <br>
To download, run the following shell script command in the tool directory.

`bash scripts/download_all_data.sh /data`

This will install the reference data to `/data/`. To check this has worked, the final folder structure of `/data/` should be the following: 

```
data
├── bfd
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffdata
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_a3m.ffindex
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffdata
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_cs219.ffindex
│   ├── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffdata
│   └── bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt_hhm.ffindex
├── mgnify
│   └── mgy_clusters_2018_12.fa
├── params
│   ├── LICENSE
│   ├── params_model_1.npz
│   ├── params_model_1_ptm.npz
│   ├── params_model_2.npz
│   ├── params_model_2_ptm.npz
│   ├── params_model_3.npz
│   ├── params_model_3_ptm.npz
│   ├── params_model_4.npz
│   ├── params_model_4_ptm.npz
│   ├── params_model_5.npz
│   └── params_model_5_ptm.npz
├── pdb70
│   ├── md5sum
│   ├── pdb70_a3m.ffdata
│   ├── pdb70_a3m.ffindex
│   ├── pdb70_clu.tsv
│   ├── pdb70_cs219.ffdata
│   ├── pdb70_cs219.ffindex
│   ├── pdb70_hhm.ffdata
│   ├── pdb70_hhm.ffindex
│   └── pdb_filter.dat
├── pdb_mmcif
│   ├── mmcif_files
│   └── obsolete.dat
├── uniclust30
│   └── uniclust30_2018_08
└── uniref90
    └── uniref90.fasta
```

Further information is available at the [alphafold github repository.](https://github.com/deepmind/alphafold)