
# Alphafold compute setup

## Overview

Alphafold requires a customised compute environment to run. The machine needs a GPU, and access to a 2.2 Tb reference data store. 

This document is designed to provide details on the compute environment required for Alphafold operation, and the Galaxy job destination settings to run the wrapper. 

For full details on Alphafold requirements, see https://github.com/deepmind/alphafold.

<br>

### HARDWARE

The machine is recommended to have the following specs: 
- 12 cores
- 80 Gb RAM
- 2.5 Tb storage
- A fast Nvidia GPU. 

As a minimum, the Nvidia GPU must have 8Gb RAM. It also requires ***unified memory*** to be switched on. <br>
Unified memory is usually enabled by default, but some HPC systems will turn it off so the GPU can be shared between multiple jobs concurrently.

<br>

### ENVIRONMENT

This wrapper runs Alphafold as a singularity container. The following software are needed:

- [Singularity](https://sylabs.io/guides/3.0/user-guide/installation.html)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

As Alphafold uses an Nvidia GPU, the NVIDIA Container Toolkit is needed. This makes the GPU available inside the running singularity container. 

To check that everything has been set up correctly, run the following

```
singularity run --nv docker://nvidia/cuda:11.0-base nvidia-smi
```

If you can see something similar to this output (details depend on your GPU), it has been set up correctly.

```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 470.57.02    Driver Version: 470.57.02    CUDA Version: 11.4     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  Tesla T4            Off  | 00000000:00:05.0 Off |                    0 |
| N/A   49C    P0    28W /  70W |      0MiB / 15109MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|  No running processes found                                                 |
+-----------------------------------------------------------------------------+
```


<br>

### REFERENCE DATA

Alphafold needs reference data to run. The wrapper expects this data to be present at `/data/alphafold_databases`. <br>
To download, run the following shell script command in the tool directory.

```
# make folders if needed
mkdir /data /data/alphafold_databases

# download ref data
bash scripts/download_all_data.sh /data/alphafold_databases
```

This will install the reference data to `/data/alphafold_databases`. To check this has worked, ensure the final folder structure is as follows: 

```
data/alphafold_databases
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


<br>

### JOB DESTINATION

Alphafold needs a custom singularity job destination to run. 
The destination needs to be configured for singularity, and some
extra singularity params need to be set as seen below. 

Specify the job runner. For example, a local runner

```
<plugin id="alphafold_runner" type="runner" load="galaxy.jobs.runners.local:LocalJobRunner"/>
```

Customise the job destination with required singularity settings. <br>
The settings below are mandatory, but you may include other settings as needed.

```
<destination id="alphafold" runner="alphafold_runner">
    <param id="dependency_resolution">'none'</param>
    <param id="singularity_enabled">true</param>
    <param id="singularity_run_extra_arguments">--nv</param>
    <param id="singularity_volumes">"$job_directory:ro,$tool_directory:ro,$job_directory/outputs:rw,$working_directory:rw,/data/alphafold_databases:/data:ro"</param>
</destination>
```

<br>

### Closing

If you are experiencing technical issues, feel free to write to help@genome.edu.au. We may be able to provide comment on setting up Alphafold on your compute environment.
