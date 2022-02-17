FROM clairemcwhite/alphafold

ARG CUDA=11.2
ARG CUDA_FULL=11.2.2

# Copy in updated alphafold repo (last commit 05/11/2021)
# https://github.com/deepmind/alphafold/tree/be37a41d6f83e4145bd4912cbe8bf6a24af80c29
RUN rm -rf /app/alphafold/alphafold
COPY alphafold /app/alphafold/

RUN conda update -qy conda \
    && conda install -y -c conda-forge \
      openmm=7.5.1 \
      cudatoolkit==${CUDA_FULL} \
      pdbfixer \
      pip \
      python=3.7

RUN wget -q -P /app/alphafold/alphafold/common/ \
  https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt

# Fix correct jax version for Cuda 11.2: https://github.com/google/jax/issues/5668
RUN pip3 install --upgrade pip \
    && pip3 install -r /app/alphafold/requirements.txt \
    && pip3 install --upgrade jax jaxlib==0.1.61+cuda112 -f \
      https://storage.googleapis.com/jax-releases/jax_releases.html
