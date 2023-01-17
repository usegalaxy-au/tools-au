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

# Build image:
# 1. Run:
#       git clone https://github.com/deepmind/alphafold/releases/tag/vx.x.x
#       cd ./alphafold
# 2. Run:
#       sudo docker build -t <repo/tag:version> -f ./path/to/this/Dockerfile .

ARG CUDA=11.4.2
FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu18.04

# FROM directive resets ARGS, so we specify again

# Must match CUDA ARG earlier, with just major.minor values (e.g., "11.4")
# To find latest version that matches the runtime version:
#   https://ubuntu.pkgs.org/18.04/cuda-amd64/

ARG CUDA_MAJOR=11
ARG CUDACMDTOOLS=11.4
ARG JAX=0.3.25
ARG JAXLIBCUDA=cuda11.cudnn805

# Vist https://storage.googleapis.com/jax-releases to find the correct one:
ARG JAXLIBURL="https://storage.googleapis.com/jax-releases/cuda11/jaxlib-0.3.25+cuda11.cudnn805-cp38-cp38-manylinux2014_x86_64.whl"
ARG JAXLIB_TMP_PATH="/tmp/jaxlib/jaxlib-0.3.25+cuda11.cudnn805-cp38-cp38-manylinux2014_x86_64.whl"

# Use bash to support string substitution.
SHELL ["/bin/bash", "-c"]

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y  --no-install-recommends \
      build-essential \
      cmake \
      cuda-command-line-tools-${CUDACMDTOOLS/./-} \
      git \
      hmmer \
      kalign \
      tzdata \
      wget \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y \
    && apt-get clean

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
RUN conda install -qy conda==4.13.0 \
    && conda install -y -c conda-forge \
      openmm=7.5.1 \
      cudatoolkit==${CUDA_VERSION} \
      pdbfixer \
      pip \
      python=3.8 \
    && conda clean --all --force-pkgs-dirs --yes

COPY . /app/alphafold

RUN wget -q -P /app/alphafold/alphafold/common/ \
  https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# Install pip packages.
RUN mkdir -p /tmp/jaxlib
RUN wget -O ${JAXLIB_TMP_PATH} ${JAXLIBURL}
RUN pip3 install --upgrade pip \
    && pip3 install -r /app/alphafold/requirements.txt --no-cache-dir \
    && pip3 install --no-cache-dir \
      --upgrade jax==${JAX} jaxlib==${JAX}+${JAXLIBCUDA} -f $(dirname $JAXLIB_TMP_PATH)
RUN rm -rf $(dirname $JAXLIB_TMP_PATH)

# Apply OpenMM patch.
WORKDIR /opt/conda/lib/python3.8/site-packages
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
