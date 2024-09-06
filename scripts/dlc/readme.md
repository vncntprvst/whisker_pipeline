### Run DLC analysis

On the cluster:

```bash
ssh om7
cd /om/user/$USER/code/dlc
sbatch dlc_video_analysis_singularity.sh /path/to/video/files
```
(you can also directly connect and go to the script directory, e.g., `ssh -t om7 "cd /om/user/<user>/code/whisker_pipeline/scripts/dlc && bash"`).

In addition to processing videos, there are three options: 
* Filter the labels
* Plots the trajectories
* Create labeled videos

To run the script with these options, use a command following this pattern:
```bash
SOURCE_PATH=/nese/mit/group/fan_wang/all_staff/Vincent/Ephys/whisker_asym/sc005/sc005_1213/
CONFIG_FILE=/om/user/$USER/data/whisker_asym/face_poke-Vincent-2024-02-29/config.yaml
sbatch dlc_video_analysis_singularity.sh $SOURCE_PATH $CONFIG_FILE True True True
```

Filtering and plotting are true by default, while creating labeled videos is false.

To edit script files, either edit them locally and upload via WinSCP, or ssh to Openmind, request compute node (e.g., `ssh -t om7 "salloc -n 1 -t 01:00:00"`), then update the `HostName nodeXXX` in the SSH `config` file and open a remote window in VSCode with `Remote Explorer > Remotes (Tunnels/SSH)`. 

### Run the DLC GUI

On a local machine  
- with an environment: 
```bash
cd /home/wanglab/data
conda activate DEEPLABCUT
python -m deeplabcut
```
- with a container:  
```bash
docker run -it --rm \
    --gpus all \
    -v /home/wanglab/data:/data \
    deeplabcut/deeplabcut:latest-gui \
    /usr/bin/python3 -m deeplabcut
```

On a remote machine with x11 forwarding, with environment:  
```bash
See settings for the [local machine](https://x410.dev/cookbook/built-in-ssh-x11-forwarding-in-powershell-or-windows-command-prompt/).  
```bash
- On the local machine
    * Check your built-in SSH client version
    ```bash
    ssh -V
    ```
    It should show `OpenSSH_for_Windows_8.1p1, LibreSSL 3.0.2`, or later.
    * Set DISPLAY environment variable for Windows 
    In a Windows Command Prompt, run:
    ```bash
    set DISPLAY=127.0.0.1:0.0
    ```
    If you want to permanently add the DISPLAY environment variable to Windows, you can setx command:
    ```bash
    setx DISPLAY "127.0.0.1:0.0"
    ```
    * Install the VcXsrv X server (for Windows)
    Download and install the VcXsrv Windows X Server from https://github.com/marchaesen/vcxsrv/releases/. Select the most recent version and download the installer, e.g., `vcxsrv-64.21.1.13.0.installer.exe` (64-bit version).
    * Start the VcXsrv X server with support for OpenGL. You can launch the X server service in the background by running `xlaunch.exe`. Make sure the "Disable access control" option is not checked.
    * Start the SSH session with -Y option
    ```bash
    ssh -Y user@remote
    ```
- On the remote machine
    * If you want to check that the DISPLAY environment variable is set correctly and that the X server is running, you can run the following commands:
    ```bash
    echo $DISPLAY
    xclock
    ```
    * Install the DeepLabCut environment
    * Start the DeepLabCut GUI
    ```bash
    conda activate DEEPLABCUT
    python -m deeplabcut
    ```

On the cluster, with container:  
- Open XFast desktop
- Open a terminal and request a GPU node
```bash
srun -n 4 --x11 --gres=gpu:1 --mem=16G -t 01:00:00 --pty bash
```
- Start the GUI
```bash
module load openmind8/apptainer/1.1.7
singularity exec --nv -B /om/user/$USER/data:/data /om2/group/wanglab/images/deeplabcut_latest-gui.sif /usr/bin/python3 -m deeplabcut
```
