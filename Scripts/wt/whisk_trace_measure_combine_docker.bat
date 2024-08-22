@echo off

REM Example:
REM whisk_trace_measure_combine.bat "home/wanglab/data/whisker_asym/sc014/sc014_0325" "sc014_0325_001_TopCam0.mp4" "sc014_0325_001" "/home/wanglab/scripts/whisk" "16"

set HDF5_USE_FILE_LOCKING=FALSE

REM Data info
set dataDir=%1
if not defined dataDir set dataDir=%cd%
set fName=%2
@REM if not defined fName, look for the first mp4 file
if not defined fName (
    for /f "delims=" %%a in ('dir /b /a-d %dataDir%\*.mp4') do set fName=%%~na
)
set baseName=%3
if not defined baseName set baseName=chunk

set scripts_dir=%4
if not defined scripts_dir set scripts_dir=%cd%

set nproc=%5
if not defined nproc set nproc=40

echo dataDir: %dataDir%
echo fName: %fName%
echo baseName: %baseName%

REM Cutting video in halves and measure
docker run --rm -v %dataDir%:/data -v %scripts_dir%:/scripts wanglabneuro/whisk-ww:latest python /scripts/wt_trace_measure.py /data/%fName% -s -b %baseName% -p %nproc%

REM And combine to export
docker run --rm -v %dataDir%:/data -v %scripts_dir%:/scripts wanglabneuro/whisk-ww:latest python /scripts/combine_sides.py /data/ %fName% hdf5