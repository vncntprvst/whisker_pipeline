#!/bin/bash

# Build Docker image
docker build \
    --build-arg CUDA_VERSION=11.4.3 \
    --build-arg CUDNN_VERSION=8 \
    --build-arg DEEPLABCUT_VERSION=2.3.5 \
    --build-arg UBUNTU_VERSION=20.04 \
    -t wanglabneuro/deeplabcut:latest-core \
    -t wanglabneuro/deeplabcut:latest-core2.3.5-cuda11.4.3 \
    -f Dockerfile-core .

# Push to Docker registry
docker push --all-tags wanglabneuro/deeplabcut

# Convert Docker image to Singularity image
# Requires Singularity installed on your system.
if ! command -v apptainer &> /dev/null
then
    echo "apptainer could not be found"
    echo "Please install apptainer from https://apptainer.org/docs/admin/main/installation.html#install-ubuntu-packages"
    exit
else
    # If a hash file exists, check the hash matches the current Docker image. If not, build a new Singularity image.
    if [ -f "deeplabcut_latest-core.sif.hash" ]; then
        if [ "$(docker inspect wanglabneuro/deeplabcut:latest-core --format='{{.Id}}')" == "$(cat deeplabcut_latest-core.sif.hash)" ]; then
            echo "Docker image has not changed. Not building Singularity image."
            build_singularity=0
        else
            echo "Docker image has changed. Building Singularity image."
            build_singularity=1
        fi
    else
        echo "Hash file not found. Building Singularity image."
        build_singularity=1
    fi
          
    if [ $build_singularity -eq 1 ]; then
        echo "Building Singularity image."
        # docker login
        apptainer build -F deeplabcut_latest-core.sif docker://wanglabneuro/deeplabcut:latest-core 
        # docker logout
        # store a hash of the Docker image in a file
        docker inspect wanglabneuro/deeplabcut:latest-core --format='{{.Id}}' > deeplabcut_latest-core.sif.hash
    fi    
            
fi

# If the .env script exists, get the HPCC_IMAGE_REPO variable
if [ -f "../.env" ]; then
    echo "Get server information from .env file."
    while IFS='=' read -r key value; do
        if [[ $key != \#* ]]; then
            export "$key=$value"
        fi
    done < "../.env"
    export SSH_HPCC_IMAGE_REPO="${SSH_NODE}:${HPCC_IMAGE_REPO}"
fi

# check if hppc_image_repo variable exists
if [ -n "${SSH_HPCC_IMAGE_REPO+x}" ]; then
    echo "Copying Singularity image to HPCC."
    rsync -aP deeplabcut_latest-core.sif "$SSH_HPCC_IMAGE_REPO/"
else
    echo "HPPC_IMAGE_REPO variable not set. Not copying to HPPC."
fi