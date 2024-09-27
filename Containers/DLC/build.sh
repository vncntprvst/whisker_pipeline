#!/bin/bash
# Script to create DeepLabCut Docker images
docker build \
    --build-arg CUDA_VERSION=11.4.3 \
    --build-arg CUDNN_VERSION=8 \
    --build-arg DEEPLABCUT_VERSION=2.3.5 \
    --build-arg UBUNTU_VERSION=20.04 \
    -f Dockerfile-core \
    -t wanglabneuro/deeplabcut:latest-core \
    -t wanglabneuro/deeplabcut:latest-core2.3.5-cuda11.4.3 . \
    --no-cache


## Versions
# tag latest-core2.3.5-cuda11.4.3
# CUDA_VERSION: 11.4.3 / CUDNN_VERSION: 8 / DEEPLABCUT_VERSION: 2.3.5 / UBUNTU_VERSION: 20.04

## Tests
# docker run --rm -it wanglabneuro/deeplabcut:latest-core /usr/bin/python3 -c "import deeplabcut; print(deeplabcut.__version__)"
# singularity exec docker://wanglabneuro/deeplabcut:latest-core /usr/bin/python3 -c "import deeplabcut; print(deeplabcut.__version__)"
