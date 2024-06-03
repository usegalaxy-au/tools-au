# GPU-tools-test

Some test wrappers to see if we can talk to the GPU from our tool development
environment.

## Setup

The main thing is to add a singularity (apptainer) destination to your job_conf file and to include `--nv` as a `singularity_run_extra_arguments`

```xml
<?xml version="1.0"?>
<job_conf>
    <plugins>
        <plugin id="local" type="runner" load="galaxy.jobs.runners.local:LocalJobRunner" workers="1"/>
    </plugins>
    <destinations default="singularity">
        <destination id="local" runner="local"/>
        <destination id="singularity" runner="local">
            <param id="singularity_enabled">true</param>
            <param id="singularity_run_extra_arguments">--nv --writable-tmpfs</param>
            <env id="LC_ALL">C</env>
            <env id="SINGULARITY_CACHEDIR">/tmp/singularity/cache</env>
            <env id="SINGULARITY_TMPDIR">/tmp</env>
        </destination>
    </destinations>
</job_conf>
```

Then run planemo like this: 

```bash
planemo test \
    --job_config_file /path/to/job_conf.xml \
    nvidia-container-cli-info.xml
```

It should see your GPU and return some information about it.

```
   NVRM version:   525.147.05
   CUDA version:   12.0

   Device Index:   0
   Device Minor:   0
   Model:          NVIDIA A100-PCIE-40GB
   Brand:          Nvidia
   GPU UUID:       GPU-3a29f0dc-490e-1e8d-abf3-a5cfa02adcde
   Bus Location:   00000000:00:08.0
   Architecture:   8.0
```

If that works you can try `dorado-test-basecaller.xml`

## `nvidia-container-cli-info.xml`

Pulls the nvidia `container-toolkit` and runs `nvidia-container-cli info`

## `dorado-test-basecaller.xml`

Pulls the ONT `dorado` container and basecalls a small .pod5 file.
