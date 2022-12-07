function videoFiles=ListVideoFiles(sessionDir)
videoFiles = cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),...
    {'*.mp4','*.avi'},'UniformOutput', false);
videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
videoFiles=videoFiles(~cellfun(@(flnm) contains(flnm,{'webcam';'Webcam'}),...
    {videoFiles.name})); % by folder name
end