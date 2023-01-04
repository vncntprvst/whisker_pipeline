function [whiskingParams,splitUp]=GetWhiskingParams(sessionDir,videoFiles)

if ~exist(fullfile(sessionDir,'WhiskerTracking','whiskerpad.json'),'file')  
    firstVideo=VideoReader(videoFiles(1).name);
    % alternative with ffmpeg (not quicker, though):
    %     sysCall=['ffmpeg -y -i ' videoFiles(1).name ' -vf "select=eq(n\,0)" -vframes 1 -q:v 3 firstFrame.jpg'];
    %     disp(sysCall); system(sysCall);
    %     vidFrame=imread('firstFrame.jpg');

    [whiskingParams,splitUp]=WhiskingFun.DrawWhiskerPadROI(firstVideo);
    [whiskingParams.FileName]=deal(firstVideo.Name);
    [whiskingParams.FileDir]=deal(firstVideo.Path);
    if ~isfolder('WhiskerTracking'); mkdir('WhiskerTracking'); end
    WhiskingFun.SaveWhiskingParams(whiskingParams,fullfile(sessionDir,'WhiskerTracking'))
else
    whiskingParams = jsondecode(fileread(fullfile(sessionDir,'WhiskerTracking','whiskerpad.json')));
    switch size(whiskingParams,1); case 1; splitUp='No'; case 2; splitUp='Yes'; end
end



