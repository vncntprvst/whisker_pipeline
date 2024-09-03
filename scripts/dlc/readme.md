### Run analysis

On the cluster:

```bash
ssh om7
cd /om/user/$USER/code/dlc
sbatch dlc_video_analysis_singularity.sh /path/to/video/files
```

### Run the GUI

On a local machine, with container:  
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
srun --pty --x11 --gres=gpu:1 --mem=16G --time=1:00:00 /bin/bash
```
- Start the GUI
```bash
module load openmind8/apptainer/1.1.7
singularity exec --nv -B /om/user/$USER/data:/data /om2/group/wanglab/images/deeplabcut_latest-gui.sif /usr/bin/python3 -m deeplabcut
```