#!/bin/sh
#SBATCH -t 04:00:00
#SBATCH -n 4    
#SBATCH --mem=12G
#SBATCH --gres=gpu:a100:1                       # For any other GPU, ask --gres=gpu:1, and next line SBATCH --constraint=24GB  (or 32GB)
#SBATCH --job-name=dlc_video_analysis    
#SBATCH -o ./slurm_logs/dlc_video_analysis_sing-%j.out
#SBATCH --mail-type=ALL

# Dynamically set mail-user
scontrol update job $SLURM_JOB_ID MailUser=$USER@mit.edu

# Use the following command to submit the job:
# sbatch dlc_video_analysis_singularity.sh [src_video_dir] [config_file] [filter_labels] [plot_trajectories] [create_labeled_video]

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

# Load global settings
source ../utils/set_globals.sh $USER

SRC_VIDEO_DIR=$1
CONFIG_FILE=${2:-"$OM_BASE_DIR/$PROJECT/$DLC_NETWORK/config.yaml"}

# Assign optional flags to an associative array
declare -A flags
flags["--filter_labels"]=${3:-"True"}
flags["--plot_trajectories"]=${4:-"True"}
flags["--create_labeled_video"]=${5:-"False"}

# If filter_labels is true, handle HDF5_USE_FILE_LOCKING
if [ "${flags["--filter_labels"]}" = "True" ]; then
    export HDF5_USE_FILE_LOCKING=FALSE
fi

# Set the Singularity image path
SINGULARITY_IMAGE="$IMAGE_REPO/deeplabcut_latest-core.sif"
echo "Using singularity image: $SINGULARITY_IMAGE"

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
PROJECT_DIR=$(dirname "$CONFIG_FILE")
ITERATION=$(grep "iteration" "$CONFIG_FILE" | awk '{print $2}')
DLC_MODELS_DIR="$PROJECT_DIR/dlc-models"
ITERATION_DIR="$DLC_MODELS_DIR/iteration-$ITERATION"
SHUFFLE_DIR=$(find "$ITERATION_DIR" -type d -name "*shuffle*" | sort -V | tail -n 1)
SHUFFLE_NUMBER=$(basename "$SHUFFLE_DIR" | grep -oP "shuffle\K\d+")
if [ -z "$SHUFFLE_NUMBER" ]; then
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
 
    BASE_NAME=$(basename "$(dirname "$SRC_VIDEO_DIR")")/$(basename "$SRC_VIDEO_DIR")
    DEST_VIDEO_DIR="$PROC_BASE_DIR/$BASE_NAME"
    echo "DEST_VIDEO_DIR: $DEST_VIDEO_DIR"

    mkdir -p "$DEST_VIDEO_DIR"

    rsync -Pavu --include="*.$VIDEO_TYPE" --exclude="*" "$SRC_VIDEO_DIR/" "$DEST_VIDEO_DIR/"
fi
echo -e '\n'

# Load the necessary Singularity module
if [ "$OS_VERSION" = "centos7" ]; then
    echo "Loading modules for CentOS 7."
    module load openmind/singularity/3.10.4
elif [ "$OS_VERSION" = "rocky8" ]; then
    echo "Loading modules for Rocky 8."
    module load openmind8/apptainer
else
    # Check if docker is running
    if ! docker info >/dev/null 2>&1; then
        echo "Docker is not running"
    else
        echo "Docker is running" 
    fi
fi

# Test GPU availability with error handling within the Singularity container
echo "Checking for GPU availability..."
GPU_CHECK=$(singularity exec --nv "$SINGULARITY_IMAGE" /usr/bin/python3 -c "import tensorflow as tf; print(tf.config.list_physical_devices('GPU'))" 2>&1)

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

    GPU_ID=$(echo "$GPU_CHECK" | grep -oP "name='/physical_device:GPU:\K\d+(?=')")
    if [ "$GPU_ID" != "0" ] && [ "$GPU_ID" != "1" ]; then
        GPU_ID=0
    fi
fi
echo -e '\n'

# Replace directory paths with true paths
TRUE_DEST_VIDEO_DIR=$(bash ../utils/full_path_substitution.sh $DEST_VIDEO_DIR)
TRUE_SRC_VIDEO_DIR=$(bash ../utils/full_path_substitution.sh $SRC_VIDEO_DIR)
TRUE_CONFIG_FILE=$(bash ../utils/full_path_substitution.sh $CONFIG_FILE)
TRUE_CONFIG_DIR=$(dirname "$TRUE_CONFIG_FILE")

echo "TRUE_DEST_VIDEO_DIR: $TRUE_DEST_VIDEO_DIR"
echo "TRUE_SRC_VIDEO_DIR: $TRUE_SRC_VIDEO_DIR"
echo "TRUE_CONFIG_DIR: $TRUE_CONFIG_DIR"

# Define the script directory as the directory where this script is located
SCRIPT_DIR=${SLURM_SUBMIT_DIR:-$(dirname "$0")}
echo "SCRIPT_DIR: $SCRIPT_DIR"

# Prepare the flags for the DLC command
OPT_DLC_FLAGS=""
for flag in "${!flags[@]}"; do
    if [ "${flags[$flag]}" = "True" ]; then
        OPT_DLC_FLAGS="$OPT_DLC_FLAGS $flag"
    fi
done

### Run the DeepLabCut analysis ###

# Construct the argument string
PRE_ARGS="--nv \
    -B $TRUE_DEST_VIDEO_DIR:$TRUE_DEST_VIDEO_DIR,$TRUE_SRC_VIDEO_DIR:$TRUE_SRC_VIDEO_DIR,$TRUE_CONFIG_DIR:$TRUE_CONFIG_DIR,$SCRIPT_DIR:$SCRIPT_DIR"
    
POST_ARGS="/usr/bin/python3 $SCRIPT_DIR/run_dlc_analysis.py \
    --config $TRUE_CONFIG_DIR/config.yaml --videos $TRUE_DEST_VIDEO_DIR \
    --dest_dir $TRUE_SRC_VIDEO_DIR \
    --videotype $VIDEO_TYPE --shuffle_num $SHUFFLE_NUMBER \
    --gpu $GPU_ID $OPT_DLC_FLAGS"

# Print the argument
echo "\nRunning DeepLabCut analysis with the following command:"
echo "singularity exec $PRE_ARGS $SINGULARITY_IMAGE $POST_ARGS\n"

# Make the call
singularity exec $PRE_ARGS $SINGULARITY_IMAGE $POST_ARGS

echo -e "\nDone at $(date)"