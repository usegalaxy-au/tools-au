# This Dockerfile was adapted for running on Azure CycleCloud by Felipe Ayora
# (bizdata.co.nz)

# Copyright 2021 DeepMind Technologies Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Look for latest version that matches NVIDIA drivers on the Azure GPU machines:
#   https://hub.docker.com/r/nvidia/cuda/tags?page=1&name=cudnn8-runtime-ubuntu18


# docker build -t image:tag -f Azure-Dockerfile /path/to/alphafold_v2.1.2


ARG CUDA=11.4.2
FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu18.04

# FROM directive resets ARGS, so we specify again

# Must match CUDA ARG earlier, with just major.minor values (e.g., "11.4")
# To find latest version that matches the runtime version:
#   https://ubuntu.pkgs.org/18.04/cuda-amd64/
ARG CUDA_MAJOR=11
ARG CUDACMDTOOLS=11.4
ARG JAXLIB=0.1.76
ARG JAXLIBCUDA=11.cudnn82

# Use bash to support string substitution.
SHELL ["/bin/bash", "-c"]

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      build-essential \
      cmake \
      cuda-command-line-tools-${CUDACMDTOOLS/./-} \
      git \
      hmmer \
      kalign \
      tzdata \
      wget \
    && rm -rf /var/lib/apt/lists/*

# Compile HHsuite from source.
RUN git clone --branch v3.3.0 https://github.com/soedinglab/hh-suite.git /tmp/hh-suite \
    && mkdir /tmp/hh-suite/build \
    && pushd /tmp/hh-suite/build \
    && cmake -DCMAKE_INSTALL_PREFIX=/opt/hhsuite .. \
    && make -j 4 && make install \
    && ln -s /opt/hhsuite/bin/* /usr/bin \
    && popd \
    && rm -rf /tmp/hh-suite

# Install Miniconda package manager.
RUN wget -q -P /tmp \
  https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && bash /tmp/Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda \
    && rm /tmp/Miniconda3-latest-Linux-x86_64.sh

# Install conda packages.
ENV PATH="/opt/conda/bin:$PATH"
RUN conda update -qy conda \
    && conda install -y -c conda-forge \
      openmm=7.5.1 \
      cudatoolkit==${CUDA_VERSION} \
      pdbfixer \
      pip \
      python=3.7

COPY . /app/alphafold

RUN wget -q -P /app/alphafold/alphafold/common/ \
  https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# Install pip packages.
RUN pip3 install --upgrade pip \
    && pip3 install -r /app/alphafold/requirements.txt \
    && pip3 install --upgrade jax==0.2.14 jaxlib==${JAXLIB}+cuda${JAXLIBCUDA} -f \
      "https://storage.googleapis.com/jax-releases/cuda${CUDA_MAJOR}/jaxlib-${JAXLIB}+cuda${JAXLIBCUDA}-cp37-none-manylinux2010_x86_64.whl"

# Apply OpenMM patch.
WORKDIR /opt/conda/lib/python3.7/site-packages
RUN patch -p0 < /app/alphafold/docker/openmm.patch

# Add SETUID bit to the ldconfig binary so that non-root users can run it.
RUN chmod u+s /sbin/ldconfig.real

# We need to run `ldconfig` first to ensure GPUs are visible, due to some quirk
# with Debian. See https://github.com/NVIDIA/nvidia-docker/issues/1399 for
# details.
# ENTRYPOINT does not support easily running multiple commands, so instead we
# write a shell script to wrap them up.
WORKDIR /app/alphafold
RUN echo $'#!/bin/bash\n\
ldconfig\n\
python /app/alphafold/run_alphafold.py "$@"' > /app/run_alphafold.sh \
  && chmod +x /app/run_alphafold.sh

# Removed entry point to facilitate running via Galaxy bash scripts
#ENTRYPOINT ["/app/run_alphafold.sh"]

# To build:
# 1. Run:
#       git clone https://github.com/deepmind/alphafold/releases/tag/vx.x.x
#       cd ./alphafold
# 2. Run:
#       sudo docker build -t <repo/tag:version> -f ./path/to/Dockerfile .
