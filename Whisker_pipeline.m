function Whisker_pipeline(sessionDir)
% Runs the whisker pipeline.
% sessionDir: the directory where are the video files
if nargin == 0; sessionDir = cd; end

%% List video files to process
videoFiles=ListVideoFiles(sessionDir);

%% Generate whisking param file
[whiskingParams,splitUp]=GetWhiskingParams(sessionDir,videoFiles);

%% Cut videos in 5 second chunks
CutVideos(sessionDir,videoFiles)

%% Perform whisker detection
TrackWhiskers(sessionDir,whiskingParams,splitUp)

%% Concatenate measurements and save whisker data
SaveWhiskerData(sessionDir);





