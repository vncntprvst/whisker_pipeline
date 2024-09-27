docker build \
    --build-arg CUDA_VERSION=11.4.3 \
    --build-arg CUDNN_VERSION=8 \
    --build-arg DEEPLABCUT_VERSION=2.3.5 \
    --build-arg UBUNTU_VERSION=20.04 \
    -t deeplabcut:latest-core .