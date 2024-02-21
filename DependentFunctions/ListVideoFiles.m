function videoFiles=ListVideoFiles(sessionDir)
% This function creates a list of video files that need to be processed, restricted to the following extensions: .mp4, .avi.
% It excludes files with the following substrings: webcam, Webcam.

videoFiles = cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),...
    {'*.mp4','*.avi'},'UniformOutput', false);
videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
videoFiles=videoFiles(~cellfun(@(flnm) contains(flnm,{'webcam';'Webcam'}),...
    {videoFiles.name})); % by folder name
if isempty(videoFiles)
    error('No video files found in the directory')
end
end