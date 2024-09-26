#!/bin/sh
#SBATCH -t 00:30:00
#SBATCH -n 1    
#SBATCH --job-name=behavior_video_analysis    
#SBATCH -o ./slurm_logs/behavior_video_analysis_sing-%j.out
#SBATCH --mail-type=ALL

# Dynamically set mail-user
scontrol update job $SLURM_JOB_ID MailUser=$USER@mit.edu

# Use the following command to submit the job:
# sbatch dlc_video_analysis_singularity.sh 

# Decide which parts of the pipeline to run
RUN_DEEPLABCUT=True
RUN_WHISKER_TRACKING=True

echo -e '\n'
echo '#########################'
echo '##  Transfer files     ##'
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
source ./utils/set_globals.sh $USER

SRC_VIDEO_DIR=$1
echo "Source video directory: $SRC_VIDEO_DIR"
BASE_NAME=$(basename "$(dirname "$SRC_VIDEO_DIR")")/$(basename "$SRC_VIDEO_DIR")
echo "Base name: $BASE_NAME"

# List of accepted video formats
ACCEPTED_FORMATS="mp4|avi|mov"

# Determine the video type from the files in the source directory
VIDEO_TYPE=$(ls $SRC_VIDEO_DIR | grep -o -m 1 -P "\.($ACCEPTED_FORMATS)$" | grep -o -P '\w+$')

# Check if VIDEO_TYPE is empty and handle the case
if [ -z "$VIDEO_TYPE" ]; then
  echo "No accepted video formats found in the source directory."
  exit 1
fi

# Determine if SRC_VIDEO_DIR is already within the scratch directory structure
if [[ "$SRC_VIDEO_DIR" == "$SCRATCH_ROOT"* ]]; then
    # echo "Source directory is already within the scratch space."
    DEST_VIDEO_DIR="$SRC_VIDEO_DIR"
else
    # echo "Source directory is not in the scratch space. Copying files..."

    DEST_VIDEO_DIR="$PROC_BASE_DIR/$BASE_NAME"
    echo "DEST_VIDEO_DIR: $DEST_VIDEO_DIR"

    mkdir -p "$DEST_VIDEO_DIR"

    rsync -Pavu --include="*.$VIDEO_TYPE" --exclude="*" "$SRC_VIDEO_DIR/" "$DEST_VIDEO_DIR/"
fi
echo -e '\n'

# Replace directory paths with true paths
TRUE_DEST_VIDEO_DIR=$(bash ./utils/full_path_substitution.sh $DEST_VIDEO_DIR)
# TRUE_SRC_VIDEO_DIR=$(bash ../utils/full_path_substitution.sh $SRC_VIDEO_DIR)

# echo "DEST_VIDEO_DIR: $TRUE_DEST_VIDEO_DIR"
# echo "SRC_VIDEO_DIR: $TRUE_SRC_VIDEO_DIR"

# Define the script directory as the directory where this script is located
# SCRIPT_DIR=${SLURM_SUBMIT_DIR:-$(dirname "$0")}
# echo "SCRIPT_DIR: $SCRIPT_DIR"

### Run the DeepLabCut analysis script ###
if [ "$RUN_DEEPLABCUT" = True ]; then

    echo -e '\n'
    echo '##########################'
    echo '##  Running DeepLabCut  ##'
    echo '##########################'
    echo -e '\n'

    DLC_JOB_ID=$(sbatch --mail-user="$EMAIL" ./dlc/dlc_video_analysis_container.sh "$TRUE_DEST_VIDEO_DIR" "--filter_labels" "--plot_trajectories" | awk '{print $NF}')

    echo "Running DLC analysis with job ID: $DLC_JOB_ID"
fi

### Run the whisker tracking script ###
if [ "$RUN_WHISKER_TRACKING" = True ]; then

    echo -e '\n'
    echo '################################'
    echo '##  Running whisker tracking  ##'
    echo '################################'
    echo -e '\n'

    WT_JOB_ID=$(sbatch --mail-user="$EMAIL" ./wt/whisker_tracking_container.sh "$TRUE_DEST_VIDEO_DIR" "200" | awk '{print $NF}')

    echo "Running whisker tracking with job ID: $WT_JOB_ID"
fi

echo -e "\nDone launching jobs at $(date)"