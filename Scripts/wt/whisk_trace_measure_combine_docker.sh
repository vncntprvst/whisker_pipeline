#!/bin/bash

# Example:
# ./whisk_trace_measure_combine.sh "home/wanglab/data/whisker_asym/sc014/sc014_0325" "sc014_0325_001_TopCam0.mp4" "sc014_0325_001" "/home/wanglab/scripts/whisk" "16"

export HDF5_USE_FILE_LOCKING=FALSE

# Data info
dataDir=$1
if [ -z "$dataDir" ]; then dataDir=$PWD; fi
fName=$2
# if fName is not defined, look for the first mp4 file
if [ -z "$fName" ]; then fName=$(ls $dataDir/*.mp4 | head -n 1); fi
baseName=$3
if [ -z "$baseName" ]; then baseName="chunk"; fi

scripts_dir=$4
if [ -z "$scripts_dir" ]; then scripts_dir=$PWD; fi

nproc=$5
if [ -z "$nproc" ]; then nproc=40; fi

echo "dataDir: $dataDir"
echo "fName: $fName"
echo "baseName: $baseName"

# Cutting video in halves and measure
docker run --rm -v $dataDir:/data -v $scripts_dir:/scripts wanglabneuro/whisk-ww:latest python /scripts/wt_trace_measure.py /data/$fName -s -b $baseName -p $nproc

# And combine to export
docker run --rm -v $dataDir:/data -v $scripts_dir:/scripts wanglabneuro/whisk-ww:latest python /scripts/combine_sides.py /data/ $fName hdf5