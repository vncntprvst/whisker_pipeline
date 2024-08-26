#### DLC
**1**
sbatch dlc_video_analysis.sh /nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc017/sc017_0701

No results saved ... adding export to csv, and destination folder = source folder

Job ID: 38042002
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:42:35
CPU Efficiency: 4.09% of 17:22:08 core-walltime
Job Wall-clock time: 01:05:08
Memory Utilized: 3.85 GB
Memory Efficiency: 24.07% of 16.00 GB

tried again:
sbatch dlc_video_analysis.sh /nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc017/sc017_0701

**4**
First working job with dlc_video_analysis_singularity.sh
SOURCE_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc005/sc005_1213/
VIDEO_PATH=/weka/scratch/tmp/Vincent/whisker_asym/sc005/sc005_1213/
mkdir -p $VIDEO_PATH
rsync -Pavu --include="*.avi" --include="*.mp4" --exclude="*" $SOURCE_PATH $VIDEO_PATH

VIDEO_PATH=/weka/scratch/tmp/Vincent/whisker_asym/sc005/sc005_1213/
sbatch dlc_video_analysis_singularity.sh $VIDEO_PATH
```bash
Job ID: 38087926
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 16
CPU Utilized: 00:16:59
CPU Efficiency: 8.86% of 03:11:44 core-walltime
Job Wall-clock time: 00:11:59
Memory Utilized: 5.91 GB
Memory Efficiency: 73.86% of 8.00 GB
```

File already copied to destination folder, then ~12 minutes to process the video (size 579MB).

**5**
Try two big videos with copy.
VIDEO_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc012/sc012_0119
```bash
 ll /nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc012/sc012_0119
-rw-r--r-- 1 prevosto nese_fan_wang_all_lab 3661674770 Jan 19  2023 sc012_0119_001_20230119-190517_HSCam.avi
-rw-r--r-- 1 prevosto wanglab               3087126218 Jan 19  2023 sc012_0119_002_20230119-192432_HSCam.avi
-rw-r--r-- 1 prevosto wanglab               1801893306 Jan 19  2023 sc012_0119_003_20230119-193528_HSCam.avi
```
sbatch dlc_video_analysis_singularity.sh $VIDEO_PATH
