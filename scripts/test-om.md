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
sc012_0119_001_20230119-190517_HSCam.avi
`100%|█████████▉| 363500/363508 [1:06:40<00:00, 84.03it/s]`
sc012_0119_003_20230119-193528_HSCam.avi
`100%|█████████▉| 178800/178885 [35:16<00:01, 83.77it/s]`

**6**
Miao's job with A100:
```bash
Job ID: 38108987
Cluster: openmind7
User/Group: miaomjin/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 4
CPU Utilized: 00:16:19
CPU Efficiency: 21.95% of 01:14:20 core-walltime
Job Wall-clock time: 00:18:35
Memory Utilized: 6.87 GB
Memory Efficiency: 85.89% of 8.00 GB
...
1,013,568,658 100%   12.94MB/s    0:01:14
sent 1,013,816,293 bytes  received 38 bytes  13,428,030.87 bytes/sec
...
100%|██████████| 100800/100800 [16:00<00:00, 128.27it/s]
101808it [16:08, 129.43it/s]
```

**7**
Job with A100 on two videos (already in scratch space, 606MB and 364MB).
```bash
ll /om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630/
-rw-r--r-- 1 prevosto wanglab 635957494 Jun 30  2023 sc016_0630_001_TopCam0.mp4
-rw-r--r-- 1 prevosto wanglab 381930622 Jun 30  2023 sc016_0630_002_TopCam0.mp4
```
Timed out ! Just too many frames to process (1328958 and 786933):
```bash
Job ID: 38152211
Cluster: openmind7
User/Group: prevosto/wanglab
State: TIMEOUT (exit code 0)
Nodes: 1
Cores per node: 4
CPU Utilized: 00:00:05
CPU Efficiency: 0.01% of 14:00:40 core-walltime
Job Wall-clock time: 03:30:10
Memory Utilized: 7.09 GB
Memory Efficiency: 88.67% of 8.00 GB

100%|█████████▉| 1328900/1328958 [2:37:51<00:00, 133.98it/s]
53%|█████▎    | 417057/786933 [49:23<45:20, 135.98it/s]slurmstepd: error: *** JOB 38152211 ON node102 CANCELLED AT 2024-09-04T16:51:00 DUE TO TIME LIMIT ***
```

**Additional tests**
Filter predictions:  
```bash
srun -n 4 --gres=gpu:1 --mem=16G -t 01:00:00 --pty bash
cd /om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630/
conda activate DEEPLABCUT
export HDF5_USE_FILE_LOCKING=FALSE
ipython -i
```
```python
import deeplabcut as dlc
config_path = '/weka/scratch/weka/wanglab/prevosto/data/whisker_asym/face_poke-Vincent-2024-02-29/config.yaml'
dlc.filterpredictions(config_path, ['/om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630/sc016_0630_001_TopCam0.mp4'], videotype='mp4', shuffle=3, save_as_csv=True)
```

or equivalent with singularity:  
```bash
srun -n 4 --gres=gpu:1 --mem=16G -t 01:00:00 --pty bash
module load openmind/singularity/3.10.4
export HDF5_USE_FILE_LOCKING=FALSE
data_path="/om/scratch/tmp/Vincent/whisker_asym/sc016/sc016_0630"
config_path="/weka/scratch/weka/wanglab/prevosto/data/whisker_asym/face_poke-Vincent-2024-02-29"
image_path="/om2/group/wanglab/images/deeplabcut_latest-core.sif"
singularity exec -B "$data_path:/data" -B "$config_path:/config" "$image_path" /usr/bin/python3 -c "import deeplabcut as dlc; dlc.filterpredictions('/config/config.yaml', ['/data/sc016_0630_001_TopCam0.mp4'], videotype='mp4', shuffle=3, save_as_csv=True)"
```

Plot trajectories:  
```bash
singularity exec -B "$data_path:/data" -B "$config_path:/config" "$image_path" /usr/bin/python3 -c "import deeplabcut as dlc; dlc.plot_trajectories('/config/config.yaml', ['/data/sc016_0630_001_TopCam0.mp4'], videotype='mp4', shuffle=3, filtered=True)"
```

Create Labeled Videos:  
```bash
singularity exec -B "$data_path:/data" -B "$config_path:/config" "$image_path" /usr/bin/python3 -c "import deeplabcut as dlc; dlc.create_labeled_video('/config/config.yaml', ['/data/sc016_0630_001_TopCam0.mp4'], videotype='mp4', shuffle=3, filtered=True)"
```

**8**
Testing added options on small video first
```bash
SOURCE_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc005/sc005_1213/
CONFIG_FILE=/weka/scratch/weka/wanglab/prevosto/data/whisker_asym/face_poke-Vincent-2024-02-29/config.yaml
sbatch dlc_video_analysis_singularity.sh $SOURCE_PATH $CONFIG_FILE True True True
```
```bash
Job ID: 38161352
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 4
CPU Utilized: 00:50:40
CPU Efficiency: 40.17% of 02:06:08 core-walltime
Job Wall-clock time: 00:31:32
Memory Utilized: 19.12 GB
Memory Efficiency: 238.95% of 8.00 GB
```

Full session, with 3 videos
```bash
-rw-r--r-- 1 prevosto nese_fan_wang_all_lab 3661674770 Jan 19  2023 sc012_0119_001_20230119-190517_HSCam.avi
-rw-r--r-- 1 prevosto wanglab               3087126218 Jan 19  2023 sc012_0119_002_20230119-192432_HSCam.avi
-rw-r--r-- 1 prevosto wanglab               1801893306 Jan 19  2023 sc012_0119_003_20230119-193528_HSCam.avi
```
```bash
SOURCE_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc012/sc012_0119/
sbatch dlc_video_analysis_singularity.sh $SOURCE_PATH 
```
```bash
Job ID: 38793546
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 4
CPU Utilized: 00:01:58
CPU Efficiency: 5.82% of 00:33:48 core-walltime
Job Wall-clock time: 00:08:27
Memory Utilized: 4.06 GB
Memory Efficiency: 33.80% of 12.00 GB
```

### Whisker Tracking
First testing with environment - then with singularity.
Install the environment:
```bash
conda create -n whisker_tracking -c conda-forge -c defaults python=3.10 
conda activate whisker_tracking
conda install -c conda-forge matplotlib pandas pytables statsmodels opencv ipykernel
conda install -c conda-forge ffmpeg-python=0.2.0 svt-av1 
pip install WhiskiWrap pyarrow joblib
```

Request a node with 120 cores, 32GB of memory:
```bash
srun -n 120 --mem=32G -t 03:00:00 --pty bash
```
Run the script:
```bash
conda activate whisker_tracking
module load openmind8/ffmpeg/2023-05
export LD_LIBRARY_PATH=/cm/shared/openmind8/ffmpeg/2023-05/lib:$LD_LIBRARY_PATH
cd /om/user/prevosto/code/whisker_pipeline/Python
file_path="/om/scratch/tmp/Vincent/whisker_asym/sc012/test_full_length/"
file_name="sc012_0119_001_20230119-190517_HSCam.avi"
base_name="sc012_0119_001"
python wt_trace_measure_no_stitch.py $file_path/$file_name -s -b $base_name -p 120
```
Fails with: 
```bash
Error loading /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/libwhisk.so: libavdevice.so.60: cannot open shared object file: No such file or directory
First-time setup: downloading necessary ffmpeg DLLs. This might take a few minutes...
Response status code: 200
FFmpeg DLLs have been successfully downloaded and extracted to /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/ffmpeg_linux64_lgpl_shared
Failed to load /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/ffmpeg_linux64_lgpl_shared/libavcodec.so.60: libswresample.so.4: cannot open shared object file: No such file or directory
Failed to load /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/ffmpeg_linux64_lgpl_shared/libavformat.so.60: libavcodec.so.60: cannot open shared object file: No such file or directory
Failed to load /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/ffmpeg_linux64_lgpl_shared/libavdevice.so.60: libavfilter.so.9: cannot open shared object file: No such file or directory
ed object file: No such file or directory
Failed to load /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/ffmpeg_linux64_lgpl_shared/libavdevice.so.60: libavfilter.so.9: cannot open shared object file: No such file or directory
Traceback (most recent call last):
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/wfile_io.py", line 134, in <module>
    cWhisk = CDLL(name)
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/ctypes/__init__.py", line 374, in __init__
    self._handle = _dlopen(self._name, mode)
OSError: libavdevice.so.60: cannot open shared object file: No such file or directory

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/weka/scratch/weka/wanglab/prevosto/code/whisker_pipeline/Python/wt_trace_measure_no_stitch.py", line 17, in <module>
    import WhiskiWrap as ww
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/__init__.py", line 36, in <module>
    from . import base
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/base.py", line 49, in <module>
    from WhiskiWrap import wfile_io
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/wfile_io.py", line 139, in <module>
    cWhisk = CDLL(name)
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/ctypes/__init__.py", line 374, in __init__
    self._handle = _dlopen(self._name, mode)
OSError: libavdevice.so.60: cannot open shared object file: No such file or directory
```

That's because installing `ffmpeg=6.0` with `conda install -c conda-forge ffmpeg=6.0` fails on openmind. 
Tried to find available ffmpeg modules `module avail 2>&1 | grep ffmpeg`, then locate it `module show openmind8/ffmpeg/2023-05` to get the lib path. That didn't help, it's already added to LIBRARY_PATH when the module is loaded.
Instead, download the binaries from: 
https://github.com/vncntprvst/whisk/releases/download/ffmpeg_6.0_dlls/ffmpeg_linux64_lgpl_shared.tar.xz
and extract them to the `whisk/bin` folder, and add the path to the `LD_LIBRARY_PATH`:
```bash
# Navigate to the whisk/bin directory
cd /om/user/prevosto/code/whisker_pipeline/Python

# Download the FFmpeg 6.0 binaries
wget https://github.com/vncntprvst/whisk/releases/download/ffmpeg_6.0_dlls/ffmpeg_linux64_lgpl_shared.tar.xz

# Extract the binaries
tar -xvf ffmpeg_linux64_lgpl_shared.tar.xz

# Move the extracted binaries to the correct directory
mkdir -p whisk/bin
mv ./home/wanglab/code/whisk/whisk/bin/ffmpeg_linux64_lgpl_shared/* ./whisk/bin/

# Delete the original folder
rm -rf ./home/wanglab/code/whisk/whisk/bin/

# Remove the tar file after extraction
rm ffmpeg_linux64_lgpl_shared.tar.xz

# Add the path to the LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$PWD/whisk/bin:$LD_LIBRARY_PATH
```
But a new error appears:
```bash
Error loading /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/libwhisk.so: /lib64/libm.so.6: version `GLIBC_2.35' not found (required by /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/libwhisk.so)
Traceback (most recent call last):
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/wfile_io.py", line 134, in <module>
    cWhisk = CDLL(name)
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/ctypes/__init__.py", line 374, in __init__
    self._handle = _dlopen(self._name, mode)
OSError: /lib64/libm.so.6: version `GLIBC_2.35' not found (required by /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/libwhisk.so)

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/weka/scratch/weka/wanglab/prevosto/code/whisker_pipeline/Python/wt_trace_measure_no_stitch.py", line 17, in <module>
    import WhiskiWrap as ww
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/__init__.py", line 36, in <module>
    from . import base
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/base.py", line 49, in <module>
    from WhiskiWrap import wfile_io
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/WhiskiWrap/wfile_io.py", line 139, in <module>
    cWhisk = CDLL(name)
  File "/om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/ctypes/__init__.py", line 374, in __init__
    self._handle = _dlopen(self._name, mode)
OSError: /lib64/libm.so.6: version `GLIBC_2.35' not found (required by /om2/user/prevosto/anaconda/envs/whisker_tracking/lib/python3.10/site-packages/whisk/bin/libwhisk.so)
```

So that means the binaries are compiled with a newer version of glibc than the one available on openmind.
We have to use the singularity container instead.

#### Whisker Tracking with Interactive Session
Request a node with 120 cores, 32GB of memory:
```bash
srun -n 120 --mem=32G -t 03:00:00 --pty bash
```
Run the script with the singularity container.
Short video:
```bash
module load openmind/singularity/3.10.4
image_path="/om2/group/wanglab/images/whisk-ww-nb_latest.sif"
script_path="/om/user/prevosto/code/whisker_pipeline/Python"
file_path="/om/scratch/tmp/Vincent/whisker_asym/test/"
file_name="test.mp4"
base_name="test"
singularity exec -B $script_path:/scripts -B $file_path:/data $image_path python /scripts/wt_trace_measure.py /data/$file_name -b $base_name -s -p 120
```
Long video:
```bash
module load openmind/singularity/3.10.4
image_path="/om2/group/wanglab/images/whisk-ww-nb_latest.sif"
script_path="/om/user/prevosto/code/whisker_pipeline/Python"
file_path="/om/scratch/tmp/Vincent/whisker_asym/sc012/test_full_length/"
file_name="sc012_0119_001_20230119-190517_HSCam.avi"
base_name="sc012_0119_001"
singularity exec -B $script_path:/scripts -B $file_path:/data $image_path python /scripts/wt_trace_measure.py /data/$file_name -b $base_name -s -p 120
```


#### Whisker Tracking with Batch Script
_First short video (2511420B = 2.5MB):_
```bash
cd /om/user/$USER/code/whisker_pipeline/scripts/wt
sbatch whisk_trace_and_measure.sh /om/scratch/tmp/Vincent/whisker_asym/test/test.mp4
```
**test #1 with**
#SBATCH -t 01:00:00                 # walltime
#SBATCH -N 1                        # number of nodes in this job
#SBATCH -n 40                       # nb CPU (hyperthreaded) cores 
#SBATCH --mem=32G

Job ID: 38148330
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 40
CPU Utilized: 00:01:19
CPU Efficiency: 3.24% of 00:40:40 core-walltime
Job Wall-clock time: 00:01:01
Memory Utilized: 22.32 GB
Memory Efficiency: 69.76% of 32.00 GB

**test #2 with**
#SBATCH -t 00:10:00                 # walltime
#SBATCH -N 1                        # number of nodes in this job
#SBATCH -n 120                       # nb CPU (hyperthreaded) cores 
#SBATCH --mem=32G

Job ID: 38148362
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 00:01:06
CPU Efficiency: 1.22% of 01:30:00 core-walltime
Job Wall-clock time: 00:00:45
Memory Utilized: 42.55 GB
Memory Efficiency: 132.98% of 32.00 GB

**test #3 with**

#SBATCH -t 00:10:00                 # walltime
#SBATCH -n 200                      # nb CPU (hyperthreaded) cores 
#SBATCH --mem=64G

Job ID: 38148369
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 5
Cores per node: 40
CPU Utilized: 00:00:58
CPU Efficiency: 0.58% of 02:46:40 core-walltime
Job Wall-clock time: 00:00:50
Memory Utilized: 16.06 GB
Memory Efficiency: 5.02% of 320.00 GB

**test #4 with**
#SBATCH -t 00:10:00             # Total wall time
#SBATCH -N 5                    # number of nodes in this job
#SBATCH -n 200                  # Total number of tasks (cores)
#SBATCH --mem=12G               # Memory per node
#SBATCH --ntasks-per-node=40    # Number of tasks (cores) per node

Job ID: 38148401
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 5
Cores per node: 40
CPU Utilized: 00:01:22
CPU Efficiency: 0.64% of 03:33:20 core-walltime
Job Wall-clock time: 00:01:04
Memory Utilized: 39.75 GB
Memory Efficiency: 66.25% of 60.00 GB

_Then long video (3661674770 = 3.6GB):_
```bash
cd /om/user/$USER/code/whisker_pipeline/scripts/wt
sbatch whisk_trace_and_measure.sh /om/scratch/tmp/Vincent/whisker_asym/sc012/test_full_length/sc012_0119_001_20230119-190517_HSCam.avi
```

**test #1 with**
#SBATCH -t 02:00:00             # Total wall time
#SBATCH -N 5                    # number of nodes in this job
#SBATCH -n 200                  # Total number of tasks (cores)
#SBATCH --mem=12G               # Memory per node
#SBATCH --ntasks-per-node=40    # Number of tasks (cores) per node

slurmstepd: error: Detected 1 oom-kill event(s) in StepId=38148424.batch. Some of your processes may have been killed by the cgroup out-of-memory handler.
(also [Errno 2] No such file or directory: '/home/miniconda3/envs/WhiskiWrap/lib/python3.10/site-packages/whisk/bin/measure', but that might be a consequence of the OOM error)

Job ID: 38148424
Cluster: openmind7
User/Group: prevosto/wanglab
State: OUT_OF_MEMORY (exit code 0)
Nodes: 5
Cores per node: 40
CPU Utilized: 00:56:57
CPU Efficiency: 8.54% of 11:06:40 core-walltime
Job Wall-clock time: 00:03:20
Memory Utilized: 35.84 GB
Memory Efficiency: 59.74% of 60.00 GB

Also, I forgot that proc_num was hard coded at 120 in the batch script.

**test #2 with**
#SBATCH -t 02:00:00             # Total wall time
#SBATCH -N 2                    # number of nodes in this job
#SBATCH -n 200                  # Total number of tasks (cores)
#SBATCH --ntasks-per-node=100    # Number of tasks (cores) per node

Job ID: 38148457
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 1-04:58:10
CPU Efficiency: 38.29% of 3-03:40:00 core-walltime
Job Wall-clock time: 00:22:42
Memory Utilized: 79.38 GB
Memory Efficiency: 19.84% of 400.00 GB

So 2GB allocated per core when nothing is specified. Inefficient memory usage. 
Otherwise it worked well (22 minutes for 3.6GB video).
  left side Tracking took 793.1182224750519 seconds.
  right side Tracking took 556.4719603061676 seconds.
  Time for whole script: 1349.9060349464417 seconds (~22 minutes).

**test #3 with**
#SBATCH -t 02:00:00             # Total wall time
#SBATCH -N 2                    # number of nodes in this job
#SBATCH -n 200                  # Total number of tasks (cores)
#SBATCH --ntasks-per-node=100    # Number of tasks (cores) per node
#SBATCH --mem=32G               # Memory per node

```bash
cd /om/user/$USER/code/whisker_pipeline/scripts/wt
sbatch whisk_trace_and_measure.sh /om/scratch/tmp/Vincent/whisker_asym/sc012/test_full_length/sc012_0119_001_20230119-190517_HSCam.avi 200 sc012_0119_001
```
Again OOM error

Job ID: 38148542
Cluster: openmind7
User/Group: prevosto/wanglab
State: OUT_OF_MEMORY (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 02:27:43
CPU Efficiency: 12.21% of 20:10:00 core-walltime
Job Wall-clock time: 00:06:03
Memory Utilized: 62.81 GB
Memory Efficiency: 98.14% of 64.00 GB

**test #3 with**
#SBATCH -t 02:00:00             # Total wall time
#SBATCH -N 2                    # number of nodes in this job
#SBATCH -n 200                  # Total number of tasks (cores)
#SBATCH --ntasks-per-node=100    # Number of tasks (cores) per node
#SBATCH --mem=48G               # Memory per node

Job ID: 38148558
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 1-01:55:12
CPU Efficiency: 35.32% of 3-01:23:20 core-walltime
Job Wall-clock time: 00:22:01
Memory Utilized: 150.14 GB
Memory Efficiency: 156.40% of 96.00 GB

ok - just increase the memory a bit more, to 75GB per node.

### Combined scripts for Whisker Tracking and DLC
See `scripts/behavior_analysis_container.sh`. 

```bash
cd scripts
SOURCE_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc014/sc014_0325
sbatch --mail-user="$USER@mit.edu" behavior_analysis_container.sh $SOURCE_PATH 
```
DLC works
WT: Lots of these errors: 
  ```bash
  Error in read whisker segments (whiskbin1 format):
    Out of memory
  ```
Probably because using the same `WT` folder with the same base name for all videos.
It is not a problem with the available memory.
```bash
Job ID: 38897919
Cluster: openmind7
User/Group: prevosto/wanglab
State: CANCELLED (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 00:00:00
CPU Efficiency: 0.00% of 1-20:33:20 core-walltime
Job Wall-clock time: 00:13:22
Memory Utilized: 82.77 GB
Memory Efficiency: 55.18% of 150.00 GB
```

After fixing output paths, we do get a true OOM error:
```bash
Job ID: 38897983
Cluster: openmind7
User/Group: prevosto/wanglab
State: OUT_OF_MEMORY (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 3-01:31:08
CPU Efficiency: 40.02% of 7-15:43:20 core-walltime
Job Wall-clock time: 00:55:07
Memory Utilized: 145.25 GB
Memory Efficiency: 96.83% of 150.00 GB
```
And this one cancelled due to time limits, but memory was not fine:
```bash
Job ID: 38897984
Cluster: openmind7
User/Group: prevosto/wanglab
State: TIMEOUT (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 00:00:00
CPU Efficiency: 0.00% of 8-08:50:00 core-walltime
Job Wall-clock time: 01:00:15
Memory Utilized: 163.91 GB
Memory Efficiency: 109.27% of 150.00 GB
```
With these SBATCH DIRECTIVES:
```bash
#SBATCH -t 02:00:00             # Total wall time
#SBATCH -N 2                    # number of nodes in this job
#SBATCH -n 200                  # Total number of tasks (cores)
#SBATCH --ntasks-per-node=100   # Number of tasks (cores) per node
#SBATCH --mem=90G               # Memory per node
```
Still getting OOM for those files.
```bash
Job ID: 38898346
Cluster: openmind7
User/Group: prevosto/wanglab
State: OUT_OF_MEMORY (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 3-11:38:35
CPU Efficiency: 40.35% of 8-15:16:40 core-walltime
Job Wall-clock time: 01:02:11
Memory Utilized: 192.77 GB
Memory Efficiency: 107.09% of 180.00 GB
``` 
```bash
Job ID: 38898347
Cluster: openmind7
User/Group: prevosto/wanglab
State: OUT_OF_MEMORY (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 3-14:07:01
CPU Efficiency: 31.00% of 11-13:50:00 core-walltime
Job Wall-clock time: 01:23:21
Memory Utilized: 187.64 GB
Memory Efficiency: 104.24% of 180.00 GB
```
DLC worked well with
```bash
#SBATCH -t 04:00:00
#SBATCH -n 4    
#SBATCH --mem=12G
#SBATCH --gres=gpu:a100:1
```
The time is for both videos in the directory.
```bash
Job ID: 38898345
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 4
CPU Utilized: 03:10:41
CPU Efficiency: 29.69% of 10:42:20 core-walltime
Job Wall-clock time: 02:40:35
Memory Utilized: 8.41 GB
Memory Efficiency: 70.11% of 12.00 GB
```

Now setting `--mem=124G` in `scripts/wt/whisker_tracking_container.sh`, and 
`RUN_DEEPLABCUT=False` in `scripts/behavior_analysis_container.sh`.
```bash
cd scripts
SOURCE_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc014/sc014_0325
sbatch --mail-user="$USER@mit.edu" behavior_analysis_container.sh $SOURCE_PATH 
```
Running whisker tracking for sc014_0325_001_TopCam0.mp4 with job ID: 38899789
```bash
Job ID: 38899789
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 00:12:24
CPU Efficiency: 0.67% of 1-06:40:00 core-walltime
Job Wall-clock time: 00:09:12
Memory Utilized: 122.31 GB
Memory Efficiency: 49.32% of 248.00 GB
```

!!!! Why?  
Running whisker tracking for sc014_0325_002_TopCam0.mp4 with job ID: 38899790
```bash
Job ID: 38899790
Cluster: openmind7
User/Group: prevosto/wanglab
State: OUT_OF_MEMORY (exit code 0)
Nodes: 2
Cores per node: 100
CPU Utilized: 00:13:46
CPU Efficiency: 0.70% of 1-08:40:00 core-walltime
Job Wall-clock time: 00:09:48
Memory Utilized: 117.42 GB
Memory Efficiency: 47.35% of 248.00 GB
```
Answer: 
```
Hi Vincent,

Yes, it looks that the job requested two nodes but ran on only one node. The --mem=124G is per node. So, I suggest running your job on only one node. If you do not use MPI, running a job on two nodes does not help.

Best,
Shaohao
```
So try: 
```bash
#SBATCH -t 02:00:00             # Total wall time
#SBATCH -N 1                    # number of nodes in this job
#SBATCH -n 200                  # Total number of tasks (cores)
#SBATCH --mem=150G  
```

Comparing avi and mp4 files:
```bash
video_path="/weka/scratch/tmp/Vincent/sc014/sc014_0325/sc014_0325_001_TopCam0.mp4"
python -c "from utils.video_utils import get_video_info; get_video_info('$video_path')"
Video file: /weka/scratch/tmp/Vincent/sc014/sc014_0325/sc014_0325_001_TopCam0.mp4
Frame dimensions: 720x540
Number of frames: 783979
File size: 373769607 bytes
Weight per frame: 476.7597180536724 bytes


video_path="/om/scratch/tmp/Vincent/sc012/sc012_0119/sc012_0119_001_20230119-190517_HSCam.avi"
python -c "from utils.video_utils import get_video_info; get_video_info('$video_path')"
Video file: /om/scratch/tmp/Vincent/whisker_asym/sc012/test_full_length/sc012_0119_001_20230119-190517_HSCam.avi
Frame dimensions: 720x540
Number of frames: 363508
File size: 3661674770 bytes
Weight per frame: 10073.161443489551 bytes
```

If split in 200 frames chunks, it would be 1.9GB per chunk for the mp4 file, and 2GB per chunk for the avi file. 
Accordingly, for
120 Cores: 1.9GB * 120 = 228GB for mp4, 2GB * 120 = 240GB for avi
128 Cores: 1.9GB * 128 = 243GB for mp4, 2GB * 128 = 256GB for avi
200 Cores: 1.9GB * 200 = 380GB for mp4, 2GB * 200 = 400GB for avi

Yet, testing showed 
# sc012/sc012_0119 (.avi)
# 120 Cores: ~43 GB
# 128 Cores: ~46 GB
# 200 Cores: ~71 GB

While for mp4, there was more OOM errors, and the memory usage was higher (but maybe code has changed since then).

What seems to fail, in fact, is the step for combining the two parquet files. 
Not sure how to predict the memory usage for this step. 

```bash
#!/bin/bash                      
#SBATCH -t 03:00:00             # Total wall time
#SBATCH -N 1                    # number of nodes in this job
#SBATCH -n 120                  # Total number of tasks (cores)
#SBATCH --mem=90G

Tracing and measuring whiskers...
Creating whiskerpad parameters file /data/whiskerpad_sc014_0325_001_TopCam0.json
...
Tracing and measuring whiskers took 2875.463263988495 seconds.
Combining whisker tracking files...
> fails 

Job ID: 38902990
Cluster: openmind7
User/Group: prevosto/wanglab
State: OUT_OF_MEMORY (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 3-09:46:06
CPU Efficiency: 68.06% of 5-00:08:00 core-walltime
Job Wall-clock time: 01:00:04
Memory Utilized: 178.87 GB
Memory Efficiency: 198.75% of 90.00 GB
```
Let's go for 200GB of memory.
Again, we're getting these OOM errors for this file (and 002):
```bash
Video file: /weka/scratch/tmp/Vincent/sc014/sc014_0325/sc014_0325_001_TopCam0.mp4
Frame dimensions: 720x540
Number of frames: 783979
File size: 373769607 bytes
Weight per frame: 476.7597180536724 bytes
```

```bash
Job ID: 38903249
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 2-22:06:19
CPU Efficiency: 65.21% of 4-11:30:00 core-walltime
Job Wall-clock time: 00:53:45
Memory Utilized: 124.60 GB
Memory Efficiency: 62.30% of 200.00 GB

Job ID: 38903250
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 3-19:33:43
CPU Efficiency: 67.94% of 5-14:46:00 core-walltime
Job Wall-clock time: 01:07:23
Memory Utilized: 171.64 GB
Memory Efficiency: 85.82% of 200.00 GB
```

ok, next, let's try these avi videos:
```bash
cd scripts
SOURCE_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc012/sc012_0119
sbatch --mail-user="$USER@mit.edu" behavior_analysis_container.sh $SOURCE_PATH 
```
```bash
Job ID: 38903702
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 1-05:34:12
CPU Efficiency: 60.22% of 2-01:06:00 core-walltime
Job Wall-clock time: 00:24:33
Memory Utilized: 107.58 GB
Memory Efficiency: 53.79% of 200.00 GB

Job ID: 38903703
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 1-01:54:31
CPU Efficiency: 63.92% of 1-16:32:00 core-walltime
Job Wall-clock time: 00:20:16
Memory Utilized: 207.28 GB
Memory Efficiency: 103.64% of 200.00 GB

Job ID: 38903704
Cluster: openmind7
User/Group: prevosto/wanglab
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 14:17:41
CPU Efficiency: 55.12% of 1-01:56:00 core-walltime
Job Wall-clock time: 00:12:58
Memory Utilized: 115.97 GB
Memory Efficiency: 57.99% of 200.00 GB
```
```bash
conda activate DEEPLABCUT
video_path="/weka/scratch/tmp/Vincent/sc012/sc012_0119/sc012_0119_003_20230119-193528_HSCam.avi"
python -c "from Python.utils.video_utils import get_video_info; get_video_info('$video_path')"

Video file: /weka/scratch/tmp/Vincent/sc012/sc012_0119/sc012_0119_001_20230119-190517_HSCam.avi
Frame dimensions: 720x540
Number of frames: 363508
File size: 3661674770 bytes
Weight per frame: 10073.161443489551 bytes

Video file: /weka/scratch/tmp/Vincent/sc012/sc012_0119/sc012_0119_002_20230119-192432_HSCam.avi
Frame dimensions: 720x540
Number of frames: 306586
File size: 3087126218 bytes
Weight per frame: 10069.364608951486 bytes

Video file: /weka/scratch/tmp/Vincent/sc012/sc012_0119/sc012_0119_003_20230119-193528_HSCam.avi
Frame dimensions: 720x540
Number of frames: 178885
File size: 1801893306 bytes
Weight per frame: 10072.91447578053 bytes
```

Now with dynamic time / memory allocation:
```bash
cd scripts
SOURCE_PATH=/om/user/prevosto/data/whisker_asym/sc014/sc014_0324
sbatch --mail-user="$USER@mit.edu" behavior_analysis_container.sh $SOURCE_PATH 
```
```bash
Running DLC analysis with job ID: 38903846
Running whisker tracking for sc014_0324_001_TopCam0.mp4 with job ID: 38903847
```
```bash
Job ID: 38903847
Cluster: openmind7
User/Group: prevosto/wanglab
State: TIMEOUT (exit code 0)
Nodes: 1
Cores per node: 120
CPU Utilized: 00:00:00
CPU Efficiency: 0.00% of 5-16:54:00 core-walltime
Job Wall-clock time: 01:08:27
Memory Utilized: 120.87 GB
Memory Efficiency: 70.69% of 171.00 GB

Starting job 38903847 on node100 at Sat Sep 28 16:21:26 EDT 2024
Requested CPUs: 120 (Available CPUs: 256)
Requested memory: 175104 (Available memory: 2.0Ti)
Requested walltime: 1:08:00   
```
Was not quite done 
`Tracking for left took 1731.9378225803375 seconds.`
= 28 minutes for one side of the video.
But was maybe ~80% done for right side, and that's before merging the two sides. This may depend on compute node's CPU generation. 
Here, node100. 
> 128 physical cores (256 hyperthreads): 2x AMD EPYC 7713 Processor @2.0 GHz (64 cores each)
Prevous mp4 videos were on node108.
> 96 physical cores (192 hyperthreads): 2x AMD EPYC 7643 Processor @2.3 GHz (48 cores each)
Also, `Number of trace processes: 171`. Why? 
Memory usage was ok, though. But again that's before merging the two sides. 

Added more safety for walltime estimation.
```bash
Submitting whisker tracking for video: /weka/scratch/tmp/Vincent/sc014/sc014_0324/sc014_0324_001_TopCam0.mp4
Estimated Wall Time Needed (minutes): 90
Wall Time: 01:30:00
Estimated Memory Needed (GB): 171
Adjusted Memory (GB): 171
Running whisker tracking for sc014_0324_001_TopCam0.mp4 with job ID: 38904789
Estimated wall time: 01:30:00, Estimated memory: 171G
...
Starting job 38904789 on node114 at Sat Sep 28 18:19:51 EDT 2024
Requested CPUs: 120 (Available CPUs: 192)
Requested memory: 175104 (Available memory: 1.0Ti)
Requested walltime: 1:30:00     
...
Tracing and measuring whiskers for /data/sc014_0324_001_TopCam0.mp4...
Running whisker tracking for left face side video
Number of trace processes: 171
Output directory: /data/WT_sc014_0324_001_TopCam0
```

rsync command to copy the results to the local machine:
```bash
# rsync -Pavu om-dtn-vincent:/weka/scratch/tmp/Vincent/sc* /mnt/md0/data/Vincent/whisker_asym/
rsync -Pavu --exclude 'WT*/' om-dtn-vincent:/weka/scratch/tmp/Vincent/sc* /mnt/md0/data/Vincent/whisker_asym/
```
