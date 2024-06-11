
## Tool versions

Dorado is distributed on
[DockerHub](https://hub.docker.com/r/nanoporetech/dorado/tags) by nanoporetech,
but not tagged with a version.

That means the hash for the current version has to be hard-coded into the
wrapper. Unfortunately you have to pull a >6 GB container just to check the tool
version. At least you can update the list of models at the same time (see
below).

**Make sure you do this when you update the wrapper**!

## Basecalling models

The models are bundled in the container at `/models` and made available by the
`dorado_models.loc` file. To update the list, modify
`tool-data/dorado_models.loc.sample`. Note that if ONT remove models from the
container, doing this will also make them unavailable to Galaxy. Check the diff
before you merge.

Here's a one-liner to **replace** the contents of the loc file with the models that are bundled in the container `nanoporetech/dorado:shac2d8bc91ca2d043fed84d06cca92aaeb62bcc1cd`.

```bash
apptainer exec docker://nanoporetech/dorado:shac2d8bc91ca2d043fed84d06cca92aaeb62bcc1cd \
    ls /models | \
    awk '{print $0 "\t" $0 "\t/models/" $0}' \
    > tool-data/dorado_models.loc.sample
```