FROM clairemcwhite/alphafold

# Copy in updated alphafold repo (last commit 05/11/2021)
# https://github.com/deepmind/alphafold/tree/be37a41d6f83e4145bd4912cbe8bf6a24af80c29

RUN rm -rf /app/alphafold/alphafold
COPY alphafold /app/alphafold/
RUN pip install -r /app/alphafold/requirements.txt
