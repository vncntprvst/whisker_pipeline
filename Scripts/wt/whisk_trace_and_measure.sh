#!/bin/bash                      
#SBATCH -t 10:00:00                 # walltime
#SBATCH -n 80                       # nb CPU (hyperthreaded) cores - 40 for node078 and above. Up to 128. May be split across nodes 
#SBATCH --mem=32G
#SBATCH --mail-user=prevosto@mit.edu
#SBATCH --mail-type=BEGIN,END,FAIL,REQUEUE,TIME_LIMIT

# Template usage: sbatch scripts/whisk_trace_and_measure.sh 'file name' 'base name' 'project directory' 'data directory' 'userID'

source /etc/profile.d/modules.sh
module load openmind/singularity   
# module use /cm/shared/modulefiles
# module load openmind8/apptainer/1.1.6

# Data info
fName=$1                                    # video file name
baseName=$2                                 # used to save chunks, e.g., sc010_0207_3200
baseName="${baseName:='chunk'}"
projectDir=$3                               # project directory, e.g., data/whisker_asym
sessionDir=$4                               # session name, e.g., sc010/sc010_0207 

# User info (in case this is run on someone else' data)
userID=$5
userID="${userID:=$USER}"
# userDir="/om2/user/$userID"   
userDir="/scratch2/scratch/Wed/$userID"  

# Set directory
dataDir="$userDir/$projectDir/$sessionDir"  # where the data is
dataDir="${dataDir:=$PWD}"

# Call the whisk container 
# cd $dataDir && \
# mkdir -p "$dataDir/WT" && \
# apptainer exec \
#      -B $dataDir:/data \
#      /om2/group/wanglab/images/whisk.simg \
#      python -c "import WhiskiWrap; from WhiskiWrap import FFmpegReader; \
# 	 WhiskiWrap.interleaved_read_trace_and_measure(FFmpegReader('/data/$fName'), \
#      '/data/WT', chunk_name_pattern='$baseName%08d.tif', \
#      h5_filename='$baseName.hdf5',n_trace_processes=80)"

# With cutting video in halves
cd $dataDir && \
mkdir -p "$dataDir/WT" && \
singularity exec \
     -B $dataDir:/data -B /om2/user/prevosto/scripts/:/scripts \
     /om2/group/wanglab/images/whisk.simg \
     python /scripts/cut_trace_measure.py --input $fName --base $baseName --nproc 80

# debugging
# source /etc/profile.d/modules.sh
# module load openmind/singularity 
# cd /scratch2/scratch/Wed/vincent/whisker_asym/sc014/sc014_0324
# baseName='sc014_0324_001'
# fName='sc014_0324_001_TopCam0.mp4'
# dataDir=$PWD
