#!/bin/bash
# Install the DeepLabCut environment
# Usage: bash install_dlc_env.sh or ./install_dlc_env.sh

# Load necessary modules
module load openmind8/cuda/11.7 openmind8/cudnn/8.7.0-cuda11

# Navigate to the desired directory
mkdir -p /om/user/$USER/code
cd /om/user/$USER/code/

# Clone the DeepLabCut repository if it doesn't already exist
if [ ! -d "DeepLabCut" ]; then
    git clone https://github.com/DeepLabCut/DeepLabCut.git -b pytorch_dlc
fi

cd DeepLabCut

# Pull the latest changes from the repository
git checkout pytorch_dlc
git pull

if [ -d "/om/user/$USER/.conda/envs/DEEPLABCUT" ]; then
    echo "DeepLabCut environment already exists. Remove? (y/n)"
    read -r response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        echo "Removing DeepLabCut environment..."
        # Remove the conda environment
        conda deactivate
        conda remove -n DEEPLABCUT --all
    else
        echo "Keeping DeepLabCut environment."
    fi

# Create the conda environment if it doesn't exist
if [ ! -d "/om/user/$USER/.conda/envs/DEEPLABCUT" ]; then
    echo "Creating DeepLabCut environment..."
    conda create -n DEEPLABCUT -c conda-forge -c defaults python=3.10 pip ipython jupyter nb_conda "notebook<7.0.0" ffmpeg "pytables==3.8.0"
    conda activate DEEPLABCUT
    pip install -r requirements.txt
    pip install git+https://github.com/DeepLabCut/DeepLabCut.git@pytorch_dlc#egg=deeplabcut[gui,modelzoo,wandb]
    # Install or downgrade pyzmq if needed
    pip uninstall -y pyzmq
    pip install pyzmq==22.0.3
else
    echo "Activating existing DeepLabCut environment..."
    conda activate DEEPLABCUT
fi

echo "DeepLabCut environment is ready to use."