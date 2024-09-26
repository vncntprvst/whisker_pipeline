#!/bin/sh
#SBATCH -t 05:00:00
#SBATCH -n 16    
#SBATCH --mem=8G
#SBATCH --gres=gpu:1
#SBATCH --constraint=24GB
#SBATCH --job-name=dlc_video_analysis    
#SBATCH -o ./slurm_logs/dlc_video_analysis-%j.out
#SBATCH --mail-type=ALL
#SBATCH --mail-user=prevosto@mit.edu

# Use the following command to submit the job:
# sbatch dlc_video_analysis.sh [src_video_dir] [config_file]

echo -e '\n'
echo '#########################'
echo '##  DLC analyze video.sh  ##'
echo '#########################'
echo -e '\n'

# Check resource availability and usage if $SLURM_JOB_ID is not empty (i.e. if we are running on a cluster)
if [ ! -z "$SLURM_JOB_ID" ]; then
    echo "Starting job $SLURM_JOB_ID on $(hostname) at $(date)"
    echo "Requested CPUs: $SLURM_CPUS_ON_NODE (Available CPUs: $(nproc --all))"
    echo "Requested memory: $SLURM_MEM_PER_NODE (Available memory: $(free -h | grep Mem | awk '{print $2}'))"
    echo "Requested walltime: $(squeue -j $SLURM_JOB_ID -h --Format TimeLimit)"
else
    echo "Starting job locally on $(hostname) at $(date)"
fi
echo -e '\n'

# Variables
SRC_VIDEO_DIR=$1
CONFIG_FILE=${2:-/om/user/prevosto/data/whisker_asym/face_poke-Vincent-2024-02-29/config.yaml}

SCRATCH_ROOT="/om/scratch/tmp/$USER"

# List of accepted video formats
ACCEPTED_FORMATS="mp4|avi|mov"

# Determine the video type from the files in the source directory
VIDEO_TYPE=$(ls $SRC_VIDEO_DIR | grep -o -m 1 -P "\.($ACCEPTED_FORMATS)$" | grep -o -P '\w+$')

# Check if VIDEO_TYPE is empty and handle the case
if [ -z "$VIDEO_TYPE" ]; then
  echo "No accepted video formats found in the source directory."
  exit 1
fi

# Determine Shuffle Number from the config file
# Extract the project directory from the config file
PROJECT_DIR=$(dirname "$CONFIG_FILE")
# Extract the iteration number from the config file
ITERATION=$(grep "iteration" "$CONFIG_FILE" | awk '{print $2}')
# Path to the dlc-models directory
DLC_MODELS_DIR="$PROJECT_DIR/dlc-models"
# Path to the iteration directory
ITERATION_DIR="$DLC_MODELS_DIR/iteration-$ITERATION"
# Find the most recent shuffle directory in the iteration directory
SHUFFLE_DIR=$(find "$ITERATION_DIR" -type d -name "*shuffle*" | sort -V | tail -n 1)
# Extract the shuffle number from the directory name
SHUFFLE_NUMBER=$(basename "$SHUFFLE_DIR" | grep -oP "shuffle\K\d+")
# Output the shuffle number
if [ -z "$SHUFFLE_NUMBER" ]; then
    # Set the shuffle number to 1 by default
    SHUFFLE_NUMBER=1
else
    echo "Most recent shuffle number: $SHUFFLE_NUMBER"
fi
echo -e '\n'

# Determine if SRC_VIDEO_DIR is already within the scratch directory structure
if [[ "$SRC_VIDEO_DIR" == "$SCRATCH_ROOT"* ]]; then
    echo "Source directory is already within the scratch space."
    DEST_VIDEO_DIR="$SRC_VIDEO_DIR"
else
    echo "Source directory is not in the scratch space. Copying files..."

    # Determine the base name (last component) of the source directory
    BASE_NAME=$(basename "$SRC_VIDEO_DIR")    
    DEST_VIDEO_DIR="$SCRATCH_ROOT/$BASE_NAME"
    echo "DEST_VIDEO_DIR: $DEST_VIDEO_DIR"

    # Create the destination directory in scratch
    mkdir -p "$DEST_VIDEO_DIR"

    # Copy only the video files of the specified type to the scratch directory
    rsync -Pavu --include="*.$VIDEO_TYPE" --exclude="*" "$SRC_VIDEO_DIR/" "$DEST_VIDEO_DIR/"
fi
echo -e '\n'

# Load the necessary modules
module load openmind8/cuda/11.7 openmind8/cudnn/8.7.0-cuda11

# Activate the DeepLabCut environment
if ! [ -z "$CONDA_EXE" ]
then
    echo "Conda is not running"
    # source /home/$USER/.bashrc
    # if /home/$USER/.conda/etc/profile.d/conda.sh exists, source it
    if [ -f "/home/$USER/.conda/etc/profile.d/conda.sh" ]; then
        source /home/$USER/.conda/etc/profile.d/conda.sh
        echo "Sourced /home/$USER/.conda/etc/profile.d/conda.sh"
    elif [ -f "/home/$USER/miniconda3/etc/profile.d/conda.sh" ]; then
        source /home/$USER/miniconda3/etc/profile.d/conda.sh
        echo "Sourced /home/$USER/miniconda3/etc/profile.d/conda.sh"
    fi
fi
conda activate DEEPLABCUT
echo -e '\n'

# Test GPU availability with error handling
GPU_CHECK=$(python -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))" 2>&1)

if [[ "$GPU_CHECK" == *"[]"* ]]; then
    echo "Error: No GPU detected. Exiting."
    exit 1
elif [[ "$GPU_CHECK" == *"Error"* || "$GPU_CHECK" == *"Traceback"* ]]; then
    echo "Error: An error occurred while checking for GPUs."
    echo "$GPU_CHECK"
    exit 1
else
    echo "GPU detected:"
    echo "$GPU_CHECK"

    # Assign the GPU ID in case it's different from 0
    GPU_ID=$(echo "$GPU_CHECK" | grep -oP "name='/physical_device:GPU:\K\d+(?=')")
    # If it's different from 0 or 1, set it to 0
    if [ "$GPU_ID" != "0" ] && [ "$GPU_ID" != "1" ]; then
        GPU_ID=0
    fi
fi
echo -e '\n'

# Run the analysis using Python
python run_dlc_analysis.py --config $CONFIG_FILE --videos $DEST_VIDEO_DIR --dest_dir $SRC_VIDEO_DIR --videotype $VIDEO_TYPE --shuffle_num $SHUFFLE_NUMBER --gpu $GPU_ID

echo -e "\nDone at $(date)"

