#!/bin/bash

docker run -d \
  --name phastest_app \
  -v /home/mthang/phastest/phastest/phastest-app-docker/sub_programs/ncbi-blast-2.3.0+:/BLAST+ \
  -v /home/mthang/phastest/phastest/phastest-app-docker/sub_programs/ncbi-blast-2.3.0+:/root/BLAST+ \
  -v /home/mthang/phastest/phastest/phastest-app-docker:/phastest-app \
  -v /home/mthang/phastest/phastest/phastest-app-docker:/root/phastest-app \
  -v /home/mthang/phastest/phastest/phastest_inputs:/phastest_inputs \
  a581cfd68afa phastest --help
