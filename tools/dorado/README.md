
## Tool versions

Dorado is distributed on
[DockerHub](https://hub.docker.com/r/nanoporetech/dorado/tags) by nanoporetech.
The containers are identified by sha256 hash, but not tagged with a version.

We can still use the containers and display the dorado version by hard-coding
both dorado version and container hash into the wrapper (see `macros.xml`).
Unfortunately you have to pull a >6 GB container and run `dorado --version` just
to check the tool version. This also prevents auto-updates of this wrapper.

You can update the list of models at the same time (see
below). **You must do this when you update the wrapper**.

## Basecalling models

The models are bundled in the container at `/models` and made available by the
`dorado_models.loc` file. 

The columns are `value`, `container_hash`, `name` and  `path`.

To update the list, modify `tool-data/dorado_models.loc.sample`.

Because models can be added and removed, models are listed **per container** in
the loc file.

Here's some code to update the loc file with models from the container with hash
`1c65eb070a9fc1d88710c4dc09b06541f96fdd28`.

```bash
export DORADO_HASH="1c65eb070a9fc1d88710c4dc09b06541f96fdd28"

apptainer exec "docker://nanoporetech/dorado:sha${DORADO_HASH}" \
    ls /models | \
    awk -v hash="${DORADO_HASH}" '{print hash "_" $0 "\t" hash "\t" $0 "\t/models/" $0}' \
    > tool-data/dorado_models.loc.sample
```

The loc file doesn't have a header, so you can keep it sorted.

```bash
cp tool-data/dorado_models.loc.sample \
    tool-data/dorado_models.loc.sample.old &&
sort -t$'\t' -k1,1V tool-data/dorado_models.loc.sample.old \
    > tool-data/dorado_models.loc.sample
```

## Kits and Barcodes

The list of acceptable kits and barcodes is not specified in the Dorado
documentation.

A list of all sequencing kits is in [`kits.cpp`](https://github.com/nanoporetech/dorado/blob/master/dorado/models/kits.cpp)

Parsed into XML with the following GNU Awk program:

```bash
gawk '
/namespace kit/ { in_kit_namespace = 1 } 
in_kit_namespace && /codes_map/ { in_map = 1; print "Entering kit::codes_map" } 
in_map && /^\s*\{/ { 
    if (match($0, /\{\s*KC::[A-Z0-9_]+,\s*\{\s*"([^"]+)"/, m)) 
        print "            <option value=\"" m[1] "\">" m[1] "</option>"; 
} 
/^\s*};/ { 
    if (in_map) { 
        print "Exiting kit::codes_map"; 
        exit 
    } 
}' kits.cpp
```

I believe the allowed barcodes are in [`barcode_kits.cpp`](https://github.com/nanoporetech/dorado/blob/master/dorado/utils/barcode_kits.cpp).

Parsed into XML with the following GNU Awk program:

```bash
gawk '
/kit_info_map/ { in_map = 1 } 
in_map && /^\s*\{/ { 
    if (match($0, /^\s*\{\s*"([^"]+)",/, m)) 
        print "            <option value=\"" m[1] "\">" m[1] "</option>"; 
} 
/^\s*};/ { if (in_map) exit }' barcode_kits.cpp
```
