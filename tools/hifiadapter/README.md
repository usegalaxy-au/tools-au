# HiFiAdapterFilt
Remove CCS reads with remnant PacBio adapter sequences and convert outputs to a compressed .fastq (.fastq.gz).

# Dependencies
- BamTools
- BLAST+

# Installation
Currently only tested on Ubuntu

# Docker
- HiFiAdapterFilt Docker is available on https://hub.docker.com/r/dmolik/pbadapterfilt

```
docker pull dmolik/pbadapterfilt
docker run -t -d -v /hifireads_data_directory_on_host_machine/:/home/genomics/HiFiAdapterFilt-master/ubuntu --name hifiadapterfilt dmolik/pbadapterfilt
docker exec -it <container_id> /bin/bash

```

See [official documentation](https://github.com/sheinasim/HiFiAdapterFilt) for more details.
