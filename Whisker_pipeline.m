function wtData=Whisker_pipeline(sessionDir,whiskParams,cutVids,trackWhisk,collateData,loadData)
% Runs the whisker pipeline.
% sessionDir: the directory where are the video files
if nargin == 0; sessionDir = cd; end
if nargin < 2; whiskParams = true; end
if nargin < 3; cutVids = true; end
if nargin < 4; trackWhisk = true; end
if nargin < 5; collateData = true; end
if nargin < 6; loadData = false; end

%% List video files to process
videoFiles=ListVideoFiles(sessionDir);

%% Generate whisking param file
if whiskParams
    GetWhiskingParams(sessionDir,videoFiles);
end

if ~system('docker -v')
    % User whisk container
    DockerTrace(videoFiles);
else
    %% Cut videos in 5 second chunks
    if cutVids
        overWrite = true; % overwrite files? true / false / 'missing_only'
        CutVideos(sessionDir,videoFiles,overWrite);
    end

    %% Perform whisker detection
    if trackWhisk
        overWrite = false; % overwrite files?
        TrackWhiskers(sessionDir);
    end
end

%% Concatenate measurements and save whisker data
if collateData
    whiskerDataList=SaveWhiskerData(sessionDir);
end

%% Load
if loadData
    if isstring(loadData) || ischar(loadData)
        fName=loadData;
    elseif exist("whiskerDataList", "var")
        fName=whiskerDataList{1};
    end
    wtData=load(fName);
end

