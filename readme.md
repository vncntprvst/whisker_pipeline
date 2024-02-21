### Installation 
* Clone or download this repository.  
* Matlab: add the Matlab folder to Matlab's path. 
Dependencies:  
  **Whisk**  
  1. See code source and download options [here](https://github.com/vncntprvst/whisk).  
  2. Add the {WhiskerTracking}/bin directory to your environment's path  
  The mex functions for loading/saving whisker and measurements files are in also available in the {WhiskerTracking}/matlab directory.  

  **Bonsai**  
  1. Download from bonsai-rx.org.  
  2. Install starter and video packages.  
  3. Add Bonsai to your environment's path (recommended but optional) 

  **Python**   
  1. Install Python (e.g., with Anaconda).  
  2. Add Python in Matlab: pyenv('Version',*executable*) -> specifies the full path to the Python executable (e.g., `C:\ProgramData\Anaconda3\python.exe`).  
  3. Install opencv. Check that the `cv2` package can be imported in python. You may need to install via `pip install opencv-contrib-python`. 

* Python:  
Create a conda environment with the `environment.yml` file: `conda env create -f environment.yml`.   
The main script is wt_trace_measure.py. 
