
# Prepare test data
Short excerpt from a video file for testing.
```bash
mkdir -p /home/wanglab/data/whisker_asym/sc012/test
cd /home/wanglab/data/whisker_asym/sc012/test
ffmpeg -ss 00:01:30 -i /mnt/md0/data/Vincent/whisker_asym/sc012/sc012_0119/sc012_0119_001_20230119-190517_HSCam.avi \
-ss 00:00:00 -t 00:00:10 -c copy /home/wanglab/data/whisker_asym/sc012/test/sc012_0119_001_20230119_10sWhisking.mp4
```
new video from Mel: 
```bash
mkdir -p /home/wanglab/data/whisker_asym/wa001/test
cd /home/wanglab/data/whisker_asym/wa001/test
ffmpeg -ss 00:01:30 -i /mnt/md0/analysis/whisker_asym/Analysis/WA001/WA001_080224/WA001_080224_01_TopCam.mp4 \
-ss 00:00:00 -t 00:03:20 -c copy /home/wanglab/data/whisker_asym/wa001/test/WA001_080224_01_TopCam_10s.mp4
```

Full length video file for testing.
```bash
mkdir -p /home/wanglab/data/whisker_asym/sc012/test_full_length
cd /home/wanglab/data/whisker_asym/sc012/test_full_length
cp /mnt/md0/data/Vincent/whisker_asym/sc012/sc012_0119/sc012_0119_001_20230119-190517_HSCam.avi .
```

# In Environment
```bash
conda activate whisker_tracking
cd /home/wanglab/code/behavior_analysis/whisker_tracking/whisker_pipeline/Python
# file_path= "/home/wanglab/data/whisker_asym/wa001/test"
file_path="/home/wanglab/data/whisker_asym/sc012/test_full_length"
# "/home/wanglab/data/whisker_asym/sc012/test"
# file_name="WA001_080224_01_TopCam_10s.mp4"
file_name="sc012_0119_001_20230119-190517_HSCam.avi"
# "sc012_0119_001_20230119_10sWhisking.mp4" 
# base_name="WA001_080224_01"
base_name="sc012_0119_001"

# Without stitching:
python wt_trace_measure_no_stitch.py $file_path/$file_name -s -b $base_name -p 40

# For midpoint:
python combine_sides.py $file_path/WT -b $base_name -ff feather -od $file_path -ft midpoint
# For combining sides, compare two scripts :
python combine_sides.py $file_path/WT -b $base_name -ff zarr -od $file_path
# Full length video: 2024-06-05 14:59:51,180 - DEBUG - Closing Zarr file: /home/wanglab/data/whisker_asym/sc012/test_full_length/sc012_0119_001.zarr
#                    Time taken: 2357.2071602344513 (~40mn)
# du -sh sc012_0119_001.zarr/
# 37G     sc012_0119_001.zarr/
python combine_sides_para_with_shared_list.py $file_path/WT -b $base_name -ff zarr -od $file_path
# 2024-06-05 18:44:59,344 - DEBUG - Final state of Zarr file: /home/wanglab/data/whisker_asym/sc012/test_full_length/sc012_0119_001.zarr
#                   Time taken: 4818.107927322388 (~80mn)
# du -sh sc012_0119_001.zarr/
# 37G     sc012_0119_001.zarr/

# With stitching to parquet:
python wt_trace_measure.py $file_path/$file_name -b $base_name -s -p 40
# nw2 full length tracking on sc012_0119_001_20230119-190517_HSCam.avi (3.4GB) 
#     left side Tracking took 3617.7535054683685 seconds.
#     right side Tracking took 2382.4000651836395 seconds.
#     Time for whole script: 6000.442905664444 seconds (~100mn)
```

# With Docker
file_path="/home/wanglab/data/whisker_asym/sc012/test"
file_name="sc012_0119_001_20230119_10sWhisking.mp4"
base_name="sc012_0119_001"
script_path="/home/wanglab/code/behavior_analysis/whisker_tracking/whisker_pipeline/Python"
nproc=40

docker run --rm -v $file_path:/data -v $script_path:/scripts wanglabneuro/whisk-ww python /scripts/wt_trace_measure_no_stitch.py /data/$file_name -s -b $base_name -p $nproc

file_path="/home/wanglab/data/whisker_asym/test"
file_name="test.mp4"
base_name="sc012_0119_001"
script_path="/home/wanglab/code/behavior_analysis/whisker_tracking/whisker_pipeline/Python"
nproc=40

docker run --rm -v $file_path:/data -v $script_path:/scripts wanglabneuro/whisk-ww python /scripts/wt_trace_measure.py /data/$file_name -b $base_name -s -p $nproc

# With whisker_tracking.sh script
```bash
file_path="/home/wanglab/data/whisker_asym/sc012/sc012_0119"
file_name="sc012_0119_002_20230119-192432_HSCam.avi"
base_name="sc012_0119_002"
nproc=40
./whisker_tracking.sh $file_path/$file_name $nproc $base_name

# Example:
./whisker_tracking.sh /home/wanglab/data/whisker_asym/sc012/sc012_0119/sc012_0119_002_20230119-192432_HSCam.avi 40 sc012_0119_002
```

TODO:
- [ ] Add h5py to Dockerfile ? 
- [ ] Why is whiskerpad_right.jpg not created? 
- [ ] Make script to call whisker tracking and DLC on the same video file. 