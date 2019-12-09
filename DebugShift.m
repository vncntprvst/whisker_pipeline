% videoParser(mainFolder, recID, varargin)

% temporary script, delete after converting to function
clear; clc

recID = 'WX002';
rawFolder = 'Z:\all_staff\Wenxi\PrVworkspace\WX002\raw data';
wsFolder = 'Z:\all_staff\Wenxi\PrVworkspace\WX002\workspace';

% properties
sweepLengthInSec = 5;
videoFrameRate = 500; % fps
numFramesPerSweep = sweepLengthInSec*videoFrameRate;

rawDirListing=dir(rawFolder);
timesFilesIdx=find(cellfun(@(files) contains(files,'_times'),...
    {rawDirListing.name} ));
frameTimes=cell(numel(timesFilesIdx),1);
for tfNum=1:numel(timesFilesIdx)
    load(fullfile(rawDirListing(timesFilesIdx(tfNum)).folder,...
        rawDirListing(timesFilesIdx(tfNum)).name));
    frameTimes=times(:,2);
    clearvars times
end

cd(wsFolder)
whiskers = Whisker.LoadWhiskers('WX002_trialNum1.whiskers'); %2500 frames per trial (500Hz * 5s)
figure; hold on
for whiskerNum=1:5
    plot(whiskers(whiskerNum).x,whiskers(whiskerNum).y)
end
