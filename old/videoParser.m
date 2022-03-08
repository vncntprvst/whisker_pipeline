% videoParser(mainFolder, recID, varargin)

% temporary script, delete after converting to function
clear; clc

recID = 'WX001';
mainFolder = 'Z:\all_staff\Wenxi\PrVworkspace\WX0\raw data';

% properties
% default properties, but make editable
sweepLengthInSec = 5;
videoFrameRate = 500; % fps
numFramesPerSweep = sweepLengthInSec*videoFrameRate;
ephysSamplingRate = 30000; % Hz, double-check
ephysScalingFactor = 0.195/1000; % mV/unit
ampBandpassFilterRange = [300 5000];

% initialize data structure 'session'
session.recordingID = recID;
session.sweepLengthInSec = sweepLengthInSec;
session.videoFrameRate = videoFrameRate;
session.numFramesPerSweep = numFramesPerSweep;
session.ephysSamplingRate = ephysSamplingRate;
session.ephysUnits = 'mV';

cd(mainFolder)

% other metadata
session.ephysBandpassRangeInHz = ampBandpassFilterRange;

% need to sort files by name (or size) if multiple files per recording to
% align together. Assume same number of files for each type (mp4,times,v)
tmp = struct2cell(dir('*times.mat'));
for i = size(tmp,2):-1:1
    timingFile{i} = tmp{1,i};
end

tmp = struct2cell(dir('*v.mat'));
for i = size(tmp,2):-1:1
    voltageFile{i} = tmp{1,i};
end

tmp = struct2cell(dir('*output.mp4'));
for i = size(tmp,2):-1:1
    videoFile{i} = tmp{1,i};
end

tmp = struct2cell(dir('*drop.txt'));
for i = size(tmp,2):-1:1
    dropFrameFile{i} = tmp{1,i};
end

%% Use timings and/or dropped frame text file to set break times for cutting ephys sweeps
for i = 1:numel(timingFile)
    t = load(timingFile{i});
    v = load(voltageFile{i});
    dropFrameTxt = fileread(dropFrameFile{i});
    
    % ? Paul already accounted for dropped frames/delay at start of recording
    % Not necessary? extract number of initial dropped frames from txt file (frame number)
    strStartExp = 'missing ';
    strStartIdx = regexp(dropFrameTxt, strStartExp);
    strEndIdx = regexp(dropFrameTxt, ' frames from');
    dropFrameStr = string(dropFrameTxt(strStartIdx+length(strStartExp):strEndIdx-1));
    dropFrameNum = str2num(dropFrameStr);
    dropFrameEphysIdx{i} = dropFrameNum/videoFrameRate*ephysSamplingRate;
    
    videoStartTime{i} = t.times(1,2);
    videoEndTime = t.times(end,2)+1/videoFrameRate;
    videoTotalTime = videoEndTime - videoStartTime{i};
    numSweepsVideo = floor(videoTotalTime/sweepLengthInSec);
    
%     ephysStartIdx{i} = floor(videoStartTime{i}*ephysSamplingRate) + dropFrameEphysIdx{i} + 1;
    ephysStartIdx{i} = floor(videoStartTime{i}*ephysSamplingRate) + 1; % only timings shift
%     ephysStartIdx{i} = dropFrameEphysIdx{i} + 1; % only drop frame shift
%     ephysStartIdx{i} = 1; % no time or drop shift
    ephysLastIdx = numel(v.voltage);
    ephysLastIdxAligned = ephysStartIdx{i} + numSweepsVideo*ephysSamplingRate*sweepLengthInSec - 1;
    appxSamplingFreq{i} = ephysLastIdx/videoEndTime;
    
    tmp = min([ephysLastIdx ephysLastIdxAligned]);
    numSweepsEphys = floor(numel(ephysStartIdx{i}:tmp)/ephysSamplingRate/sweepLengthInSec);
    ephysEndIdx{i} = tmp;
    
    numSweeps{i} = min([numSweepsVideo numSweepsEphys]);
    sweepNums{i} = 1:numSweeps{i};
    sweepStartIdx{i} = (sweepNums{i}-1)*ephysSamplingRate*sweepLengthInSec + 1;
    sweepEndIdx{i} = sweepNums{i}*ephysSamplingRate*sweepLengthInSec;
    
    videoSweepStarts{i} = 1:videoFrameRate*sweepLengthInSec:(numSweeps{i}-1)*videoFrameRate*sweepLengthInSec+1;
    videoSweepEnds{i} = sweepLengthInSec*videoFrameRate*(1:1:numSweeps{i});
    actualTimeElapsed{i} = t.times(videoSweepEnds{i},2) - t.times(videoSweepEnds{i}(1),2) + sweepLengthInSec;
    appxTimeElapsed{i} = sweepLengthInSec*(1:1:numSweeps{i});
    timeCorrection{i} = actualTimeElapsed{i} - shiftdim(appxTimeElapsed{i});
end

save('timeCorrection', 'timeCorrection');

% load each file and parse into 5s sweeps
% pre-allocate to improve speed
totalNumSweeps = nansum(cell2mat(numSweeps));
session.voltage = cell(totalNumSweeps,1);
restartTrials = zeros(numel(timingFile),1);

% Loop through each recording and parse ephys data
ephysTrialNum = 1;
for i = 1:numel(timingFile)
    clear voltageCut 
    restartTrials(i) = ephysTrialNum;
    v = load(voltageFile{i});
    voltageCut = double(v.voltage(ephysStartIdx{i}:ephysEndIdx{i}));
    voltageCut = voltageCut*ephysScalingFactor;
    for n = 1:numSweeps{i}
        session.voltage{ephysTrialNum} = voltageCut(sweepStartIdx{i}(n):sweepEndIdx{i}(n));
        if n < totalNumSweeps
            ephysTrialNum = ephysTrialNum + 1;
        end
    end
    disp(i)
end

% fill in other ephys metadata in session after all files have been read
session.trialNums = 1:totalNumSweeps;
session.numTrials = ephysTrialNum;
session.restartTrials = restartTrials;
save([recID '_session.mat'], 'session', '-v7.3');

%% trialNum is incremented after each video is written
cd(mainFolder)
trialNum = 1;
for i = 1:numel(timingFile)
    t = load(timingFile{i});
%     v = load(voltageFile{i});
    % Cut video into sweeps
    videoFReader = vision.VideoFileReader(videoFile{i});
    videoCounter = 1;
    frameEnd = numSweeps{i}*numFramesPerSweep;
    for f = 1:frameEnd
        if videoCounter==1
            tic
            newFileName = [recID '_trialNum' num2str(trialNum) '.mp4'];
            videoFWriter = vision.VideoFileWriter(newFileName, ...
                'FileFormat', 'MPEG4', 'Quality', 100);
        end
        
        videoFrame = videoFReader();
        videoFWriter(rgb2gray(videoFrame));

        if videoCounter ~= numFramesPerSweep
            videoCounter = videoCounter + 1;
        elseif videoCounter==numFramesPerSweep
            release(videoFWriter);
            pause(0.1)
            disp(num2str(trialNum));
            videoCounter = 1;
            trialNum = trialNum + 1;
            toc
        end
    end
    disp(num2str(videoCounter));
    release(videoFReader);
    release(videoFWriter);
end
disp('Done!');

%% testing
clear; clc

v = VideoReader('WX001G_trialNum1.mp4');
f = 1;
vidFrame = uint8(zeros(480,640,2500));

figure; clf
currAxes = axes;

whiskers = LoadWhiskers('WX001G_trialNum1.whiskers');
whiskers = struct2cell(whiskers);
whiskFrame = cell2mat(whiskers(2,:));
whiskX = whiskers(3,:);
whiskY = whiskers(4,:);

while hasFrame(v)
    vidFrame(:,:,f) = rgb2gray(readFrame(v));
    colormap gray
    imshow(vidFrame(:,:,f), 'Parent', currAxes); hold on
    currAxes.Visible = 'off';
    disp(num2str(f))
    
    thisFrame = find(whiskFrame==(f-1));
    for w = 1:numel(thisFrame)
        plot(whiskX{thisFrame(w)},whiskY{thisFrame(w)}, 'Color', 'c');
    end
    f = f + 1;
    pause(1/v.FrameRate); hold off
end


