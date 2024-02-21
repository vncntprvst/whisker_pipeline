#!/bin/bash                      
#SBATCH -t 02:00:00                 # walltime
#SBATCH -n 128                       # nb CPU (hyperthreaded) cores - 40 for node078 and above. Up to 128. May be split across nodes 
#SBATCH --mem=32G
#SBATCH --export=HDF5_USE_FILE_LOCKING=FALSE
#SBATCH --mail-user=prevosto@mit.edu
#SBATCH --mail-type=BEGIN,END,FAIL,REQUEUE,TIME_LIMIT

# Template usage: sbatch scripts/whisk_trace_and_measure.sh 'file name' 'base name' 'project directory' 'data directory' 'userID'

source /etc/profile.d/modules.sh
module load openmind/singularity/3.6.3 
# module use /cm/shared/modulefiles
# module load openmind8/apptainer/1.1.6

# Already set above. See here why: https://docs.nersc.gov/development/languages/python/parallel-python/#parallel-io-with-h5py
# export HDF5_USE_FILE_LOCKING=FALSE

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
userDir="/om2/user/$userID/data"
# userDir="/scratch2/scratch/Wed/$userID"  
# userDir="/scratch2/tmp/$userID"  

# Set directory
dataDir="$userDir/$projectDir/$sessionDir"  # where the data is
dataDir="${dataDir:=$PWD}"

echo "dataDir: $dataDir"
echo "fName: $fName"
echo "baseName: $baseName"

# Cutting video in halves then measure
cd $dataDir && \
mkdir -p "$dataDir/WT" && \
singularity exec \
     -B $dataDir:/data -B /om2/user/prevosto/scripts/:/scripts \
     /om2/group/wanglab/images/whisk-ww-nb.simg \
     python /scripts/cut_trace_measure.py --input /data/$fName --base $baseName --nproc 128
wait

# And combine to export
singularity exec \
    -B $dataDir:/data -B /om2/user/prevosto/scripts/:/scripts \
    /om2/group/wanglab/images/whisk-ww-nb.simg \
    python /scripts/combine_left_right_whiskers.py /data/WT

# debugging
# source /etc/profile.d/modules.sh
# module load openmind/singularity/3.6.3 
# cd /scratch2/scratch/Wed/vincent/whisker_asym/sc014/sc014_0324/test
# baseName='sc014_0324_001'
# fName='sc014_0324_001_30sWhisking.mp4'
# dataDir=$PWD

# sbatch scripts/whisk_trace_measure_combine.sh 'sc014_0324_001_30sWhisking.hdf5' 'sc014_0324_001' 'whisker_asym' 'sc014/sc014_0324/test' 'vincent'
