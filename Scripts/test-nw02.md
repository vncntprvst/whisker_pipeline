
# Prepare test data
```bash
mkdir -p /home/wanglab/data/whisker_asym/sc012/test
cd /home/wanglab/data/whisker_asym/sc012/test
ffmpeg -ss 00:01:30 -i /mnt/md0/data/Vincent/whisker_asym/sc012/sc012_0119/sc012_0119_001_20230119-190517_HSCam.avi \
-ss 00:00:00 -t 00:00:10 -c copy /home/wanglab/data/whisker_asym/sc012/test/sc012_0119_001_20230119_10sWhisking.mp4
```

# In Environment
```bash
conda activate whisker_tracking
cd /home/wanglab/code/behavior_analysis/whisker_tracking/whisker_pipeline/Python
file_path="/home/wanglab/data/whisker_asym/sc012/test"
file_name="sc012_0119_001_20230119_10sWhisking.mp4" 
base_name="sc012_0119_001"

python wt_trace_measure_no_stitch.py $file_path/$file_name -s -b $base_name -p 40

python combine_sides.py $file_path/WT -b $base_name -ff feather -od $file_path -ft midpoint
```

# With Docker
file_path="/home/wanglab/data/whisker_asym/sc012/test"
file_name="sc012_0119_001_20230119_10sWhisking.mp4"
base_name="sc012_0119_001"
script_path="/home/wanglab/code/whisker_tracking/whisker_pipeline/Python"
nproc=16

docker run --rm -v $file_path:/data -v $script_path:/scripts wanglabneuro/whisk-ww:nb-0.2.0 python /scripts/wt_trace_measure_no_stitch.py /data/$file_name -s -b $base_name -p $nproc

nb-0.2.0
