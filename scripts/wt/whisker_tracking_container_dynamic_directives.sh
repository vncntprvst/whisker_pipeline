#!/bin/bash
#SBATCH -N 1                    # number of nodes in this job
#SBATCH -n 120                  # Total number of tasks (cores)
#SBATCH --job-name=wt_measure
#SBATCH -o ./slurm_logs/wt_measure-%j.out
#SBATCH --mail-type=ALL

# Dynamically set mail-user, in case it wasn't passed by user.
# Pass the email address as an argument to get the email notification for the job status
scontrol update job $SLURM_JOB_ID MailUser=$USER@mit.edu

# In this version of the script, we remove SBATCH directives for time and memory, 
# which are set dynamically according to video type and the number of frames in the video.
# Pass them as arguments to the script instead.
# Template usage: 
# sbatch \
#     --mail-user="$EMAIL" \
#     --time="$WALL_TIME" \
#     --mem="${ESTIMATED_MEMORY_GB}G" \
#     ./whisk_trace_and_measure.sh [file_path] [proc_num] [base_name]
# SBATCH directives in static form:
# -t 03:00:00             # Total wall time
# --mem=200G              # Memory per node

echo -e '\n'
echo '##################################'
echo '##  whisk trace and measure.sh  ##'
echo '##################################'
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

# Set global variables
source ../utils/set_globals.sh $USER

# Assign input arguments to variables
file_name=$(basename "$1")  # get video file name from path
file_path=$(dirname "$1")  # get video file path
proc_num=${2:-${SLURM_CPUS_ON_NODE:-120}}  # number of processes to use; default is 120
base_name=${3:-"${file_name%.*}"}  # used to save chunks, e.g., sc010_0207_3200; if not provided, use the file name without extension
# used to save chunks, e.g., sc010_0207_3200; if not provided, use the file name

echo "File path: $file_path"
echo "File name: $file_name"
echo "Base name: $base_name"

# Locate whisker_tracking and full path substitution scripts
find_script() {
    local script_name=$1
    for path in "../../Python/$script_name" "../Python/$script_name" "../utils/$script_name" "./utils/$script_name"; do
        if [ -f $path ]; then
            echo $(realpath $path)
            return
        fi
    done
    echo -e "\e[31mError:\e[0m File \e[37;103m$script_name\e[0m not found \n"
    exit 1
}

# Get script and substitution script paths
script_path=$(find_script "whisker_tracking.py")
full_path_script=$(find_script "full_path_substitution.sh")

# Substitute full paths
export file_path=$(bash $full_path_script $file_path)
export script_path=$(bash $full_path_script $(dirname $script_path))

# Singularity image
image_path="$IMAGE_REPO/whisk-ww-nb_latest.sif"
echo "Using singularity image: $image_path"

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

# Set the working directory for whisker tracking processing 
output_dir="/data/WT_${base_name}"

# Run the script
singularity exec -B $script_path:/scripts -B $file_path:/data $image_path python /scripts/whisker_tracking.py /data/$file_name -b $base_name -s -p $proc_num -o $output_dir

# End of script
echo -e '\n'
echo "Job finished at $(date)"