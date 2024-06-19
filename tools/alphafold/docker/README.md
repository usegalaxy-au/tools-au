# What is this?

Alphafold docker is built from a modified version of the official Dockerfile

- `ENTRYPOINT` removed
- Cuda & Jax/Jaxlib dependancies updated

Build:

```sh
docker build -f ../Dockerfile -t my-alphafold-tag alphafold
```
