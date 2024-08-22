#!/bin/bash
#SBATCH --job-name=dlc_video_analysis
#SBATCH --output=dlc_video_analysis_%j.log
#SBATCH --error=dlc_video_analysis_%j.err
#SBATCH --time=04:30:00
#SBATCH --mem=16G
#SBATCH --gres=gpu:1
#SBATCH --constraint=any-gpu
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=1

# Load the necessary modules
module load openmind8/cuda/11.7 openmind8/cudnn/8.7.0-cuda11

# Activate the DeepLabCut environment
source activate DEEPLABCUT

# Test GPU availability
python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))"

# Copy data to the scratch directory
mkdir -p /om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630/
rsync -Pavu /om/user/prevosto/data/whisker_asym/sc016/sc016_0630/sc016_0630_001_TopCam0.mp4 /om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630/
rsync -Pavu /om/user/prevosto/data/whisker_asym/sc016/sc016_0630/sc016_0630_002_TopCam0.mp4 /om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630/

# Run the analysis using Python
python run_dlc_analysis.py --config /om/user/prevosto/data/whisker_asym/face_poke-Vincent-2024-02-29/config.yaml --videos /om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630/ --videotype mp4 --gpu 0



# Use the following command to submit the job:
# sbatch dlc_video_analysis.sh