This is working

```bash

singularity exec \
	-B /media,${PWD},${TMPDIR},/tmp --nv -H $(mktemp -d) --pwd ${PWD} --containall --cleanenv --writable-tmpfs \
		docker://quay.io/biocontainers/genomicconsensus@sha256:de72299d4fb4f2bd25abdb0309527c0ad5b39e3e6b1216f76456324a642962ab \
	variantCaller \
		--numWorkers 32 \
		--referenceFilename test-data/All4mer.V2.01_Insert.fa \
		--outputFilename test-data/output.fa \
		test-data/out.aligned_subreads.bam
```

But I'm getting a strange error when I run planemo.

```
Job in error state.. tool_id: genomicconsensus_arrow, exit_code: 255, stderr: FATAL:   container creation failed: mount /tmp/tmpi93gqv8c/job_working_directory/000/5->/tmp/tmpi93gqv8c/job_working_directory/000/5 error: while mounting /tmp/tmpi93gqv8c/job_working_directory/000/5: destination /tmp/tmpi93gqv8c/job_working_directory/000/5 doesn't exist in container
```

I don't know how it's running Singularity but it's not working.
