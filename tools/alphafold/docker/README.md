# What is this?

These are `alphafold` git repos copied from:
  - the `clairemcwhite/alphafold` docker container (originates from a fork/branch https://github.com/deisseroth-lab/alphafold/tree/cudnn-runtime)
  - The upstream https://github.com/deepmind/alphafold

### Diffs
- According to [the closed pull request](https://github.com/deepmind/alphafold/pull/36), the main diff is updates to Dockerfile Cuda deps in the fork
- These issues have since been resolved in the upstream
- Can probably copy the new repo into the image in a new Dockerfile `FROM clairemcwhite/alphafold`
- And hope that alphafold on pulsar can work with the new container!
  (There were lots of dependency issues...)
