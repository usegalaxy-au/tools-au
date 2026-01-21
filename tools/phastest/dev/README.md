# PHASTEST Docker Container

This version of the Docker cluster is confined to single container, and is designed to be an alternative in case multi-container Docker image is too taxing on the device performance and/or too unstable.

Note that one sequence alignment process running over entirety of the input may be extremely slow, especially with raw-sequence and contig inputs.

## What is PHASTEST

PHASTEST (PHAge Search Tool with Enhanced Sequence Translation) provides rapid identification and annotation of prophage sequences within bacterial genomes and plasmids. Compatible with genbank nucleotide records (either complete sequence of whole genome shotgun sequences), or nucleotide sequence file in FASTA format. Web service can be found at (https://phastest.ca/).

## Requirements

This is a single-container version of the Dockerized PHASTEST, and requires `Single Container Docker Image` from the (https://phastest.ca/databases). Unzipping the archive will produce directory named `phastest-docker`, where all codes relevant to running Dockerized PHASTEST are located.

Archive containing relevant database files, named `Docker Database Files` from (https://phastest.ca/databases) is also required - please place all its contents into the `/phastest-docker/phastest-app-docker/DB/` directory.

## Building the Docker Image

Image `wishartlab/phastest-docker-single` can be pulled from Docker Desktop app, or via command below:

```console
docker pull wishartlab/phastest-docker-single
```

From the directory where `Dockerfile` is present, Docker image may be built locally via running the command below:

```console
docker build -t wishartlab/phastest-docker-single .
```

Building the docker image may take up to 20-30 minutes, and up to an hour on M1 Macbook. As such, using image available from the Docker Hub is recommended.

## Starting the Cluster

Once image has been built, use `docker compose run` command to start the container and immediately begin processing queries.

```console
docker compose run phastest -i {genbank|fasta|contig} -a {accession number} -m {annotation mode} -s {sequence file name} [OPTIONS]...
```

After a confirmation message, PHASTEST container will start running.

```console
-i {genbank|fasta|contig}
    Specify input format. Accepted values are 'fasta', 'genbank', or 'contig'.
    If 'genbank' is selected, -a flag and accession number must be provided.
    If 'fasta' or 'contig' is selected, -s flag and the sequence filename must be provided.
    Please note that 'genbank' input format requires internet connection to download relevant data from NCBI.
    As such, jobs with 'genbank' input format may fail depending on the NCBI server status.

-a {accession number}
    Specify accession number for the job. For example, NC_000907.1, KF030445.1, LZPG00000000.1.
    For the WGS sequence, accession number for the master record should be provided.

-m {lite|deep}
    Specify annotation mode. Accepted values are 'deep' or 'lite'.
    If this flag is not specified, it will default to 'lite'.
    'deep' uses Prophage Database and PHAST-BSD Bacterial Database.
    'lite' uses Prophage Database and Swissprot.
    (Note: 'deep' mode may take significantly longer to complete.)

-s {sequence filename}
    Path to the raw FASTA sequence - parsed only if input-type was set to 'fasta' or 'contig'.
    Sequence with the given filename must be present in `/phastest_inputs` folder.
    For example, to run the `test.fna` job, then `test.fna` must be deposited into `/phastest_inputs` and
    docker command should be run like `docker compose run phastest -i fasta -s test.fna ...`.
    For the input type 'fasta', minimum sequence length is 1500bp.

OPTIONS:
--yes:
    Skips the confirmation message before running the PHASTEST job.

--silent:
    Mutes the output from the PHASTEST terminal.

--phage-only:
    Annotate the predicted phage region only. In default, whole genomes are scanned and annotated.
```

### Running Jobs on FASTA/Contig Sequences

For running jobs against FASTA/contig sequences, target sequence must be deposited and present within `/phastest-docker/phastest_inputs` directory. 

When running PHASTEST job, please make sure input type is set as fasta or contig, and full filename (along with the .fna or .fasta extension) is provided with the command.

```console
docker compose run phastest -i fasta -s seq_test.fna

docker compose run phastest -i contig -s contig_test.fna
```

### Running Jobs on GenBank Records

If input type is set as genbank and accession number is provided, then PHASTEST will automatically download record with given accession number and scan for prophage regions.

```console
docker compose run phastest -i genbank -a KF030445.1

docker compose run phastest -i genbank -a LZPG00000000.1
```

### Retrieving Complete Jobs

All complete jobs will be deposited in `/phastest-docker/phastest-app-docker/JOBS/{job_id}` directory. `job_id` will be sequence file's basename (in case of FASTA or contig inputs), or accession number (in case of genbank inputs).

## Stopping and Restarting the Cluster

While PHASTEST job is running, you may send SIGINT (Ctrl+C) at any time to terminate current job.

Use `docker compose down` to remove the stopped container afterwards.

## Deleting the Cluster

To remove all containers and volumes, run:

```console
docker-compose stop
docker-compose rm -f
docker container prune
```
