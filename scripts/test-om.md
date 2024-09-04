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