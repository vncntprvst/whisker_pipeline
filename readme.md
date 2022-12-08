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


MIT License

Copyright (c) 2022 Vincent Prevosto

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. 

