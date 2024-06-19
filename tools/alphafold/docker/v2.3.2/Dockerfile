# Adapted from https://github.com/google-deepmind/alphafold/blob/main/docker/Dockerfile

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

# To build:
#     VERSION=2.3.2
#     wget -O /path/to/alphafold.tar.gz "https://github.com/google-deepmind/alphafold/archive/refs/tags/v${VERSION}.tar.gz"
#     tar -xzf /path/to/alphafold.tar.gz -C /path/to/alphafold --strip-components=1
#     ln -s /path/to/alphafold
#     docker build -t "<repo/name:v${VERSION}_${BUILD}>" -f Dockerfile alphafold

ARG CUDA=11.1.1
FROM nvidia/cuda:${CUDA}-cudnn8-runtime-ubuntu18.04

# FROM directive resets ARGS, so we specify again (the value is retained if previously set).
ARG CUDA

ARG JAX_VERSION=0.3.25
ARG JAXLIB_VERSION=${JAX_VERSION}+cuda11.cudnn805

# Use bash to support string substitution.
SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    build-essential \
    cmake \
    cuda-command-line-tools-$(cut -f1,2 -d- <<< ${CUDA//./-}) \
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
ENV LD_LIBRARY_PATH="/opt/conda/lib:$LD_LIBRARY_PATH"

RUN conda install -qy conda==4.13.0 python=3.8 \
    && conda install -y -c conda-forge \
      openmm=7.5.1 \
      cudatoolkit==${CUDA_VERSION} \
      pdbfixer \
      pip \
    && conda clean --all --force-pkgs-dirs --yes

# For next release:
# RUN conda install -qy conda==24.5.0 pip python=3.11 \
#     && conda install -y -c nvidia                   \
#       cuda=12.2.2                                   \
#       cuda-tools=12.2.2                             \
#       cuda-toolkit=12.2.2                           \
#       cuda-version=12.2                             \
#       cuda-command-line-tools=12.2.2                \
#       cuda-compiler=12.2.2                          \
#       cuda-runtime=12.2.2
# RUN conda install -y -c conda-forge openmm=8.0.0 pdbfixer \
#     && conda clean --all --force-pkgs-dirs --yes

COPY . /app/alphafold

RUN wget -q -P /app/alphafold/alphafold/common/ \
    https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# Install pip packages.
RUN pip3 install --upgrade pip \
    && pip3 install -r /app/alphafold/requirements.txt \
    && pip3 install --upgrade jax==${JAX_VERSION} jaxlib==${JAXLIB_VERSION} -f \
      https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
    && pip3 install --no-cache-dir matplotlib

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
