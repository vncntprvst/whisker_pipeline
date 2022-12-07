function [whiskingParams,splitUp]=GetWhiskingParams(sessionDir,videoFiles)

if ~exist(fullfile(sessionDir,'WhiskerTracking','whiskerpad.json'),'file')  
    firstVideo=VideoReader(videoFiles(1).name);
    [whiskingParams,splitUp]=WhiskingFun.DrawWhiskerPadROI(firstVideo);
    if ~isfolder('WhiskerTracking'); mkdir('WhiskerTracking'); end
    WhiskingFun.SaveWhiskingParams(whiskingParams,fullfile(sessionDir,'WhiskerTracking'))
else
    whiskingParams = jsondecode(fileread(fullfile(sessionDir,'WhiskerTracking','whiskerpad.json')));
    switch size(whiskingParams,1); case 1; splitUp='No'; case 2; splitUp='Yes'; end
end
