### Installation 
* Clone or download this repository.  
* Add it to Matlab's path. 

### Dependencies
**Whisk**  
1. See [instructions](https://wiki.janelia.org/wiki/display/MyersLab/Whisker+Tracking) to download and install. [update 12/7/22: This link has been broken for a while. Binaries are available in the [Download](https://bitbucket.org/whiskertracking/whiskerpipeline/downloads/) section of this repository].  
2. Add the {WhiskerTracking}/bin directory to your environment's path  
The mex functions for loading/saving whisker and measurments files are in also available in the {WhiskerTracking}/matlab directory.  

**Bonsai**  
1. Download from bonsai-rx.org.  
2. Install starter and video packages.  
3. Add Bonsai to your environment's path (recommended but optional) 

**Python**   
1. Install Python (e.g., with Anaconda).  
2. Add Python in Matlab: pyenv('Version',*executable*) -> specifies the full path to the Python executable (e.g., `C:\ProgramData\Anaconda3\python.exe`).  
3. Install opencv. Check that the `cv2` package can be imported in python. You may need to install via `pip install opencv-contrib-python`.  

