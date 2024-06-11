
## Tool versions

Dorado is distributed on
[DockerHub](https://hub.docker.com/r/nanoporetech/dorado/tags) by nanoporetech,
but not tagged with a version.

That means the hash for the current version has to be hard-coded into the
wrapper. Unfortunately you have to pull a >6 GB container and run `dorado
--version` just to check the tool version.

You can update the list of models at the same time (see
below). **You must do this when you update the wrapper**.

## Basecalling models

The models are bundled in the container at `/models` and made available by the
`dorado_models.loc` file. To update the list, modify
`tool-data/dorado_models.loc.sample`. Note that if ONT remove models from the
container, doing this will also make them unavailable to Galaxy. Check the diff
before you merge.

The columns are `value`, `tool_version`, `name` and  `path`.

Here's a one-liner to **update** the loc file with the models that are bundled
in the container
`nanoporetech/dorado:shac2d8bc91ca2d043fed84d06cca92aaeb62bcc1cd`. Note that you
would use the hash for the current dorado version (obtained above), and the
dorado version is manually passed to `awk`.

```bash
apptainer exec docker://nanoporetech/dorado:shac2d8bc91ca2d043fed84d06cca92aaeb62bcc1cd \
    ls /models | \
    awk -v tv="0.7.1" '{print tv "_" $0 "\t" tv "\t" $0 "\t/models/" $0}' \
    >> tool-data/dorado_models.loc.sample
```