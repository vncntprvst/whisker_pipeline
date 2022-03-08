% videoParser2(mainFolder, recID, varargin)

% temporary script, delete after converting to function
clear; clc

recID = 'WX010';
mainFolder = 'Z:\all_staff\Wenxi\PrVworkspace\WX010\raw data';

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

% Use frame times to set break times for cutting ephys sweeps
tic
for i = numel(timingFile):-1:1
    t = load(timingFile{i});
    v = load(voltageFile{i});
    
    videoStartTime{i} = t.times(1,2);
    videoEndTime = t.times(end,2)+1/videoFrameRate;
    videoTotalTime = videoEndTime - videoStartTime{i};
    numSweepsVideo = floor(videoTotalTime/sweepLengthInSec);
    videoSweepStartIdx{i} = linspace(1,1+numFramesPerSweep*(numSweepsVideo-1),numSweepsVideo);
    videoSweepStartTimes{i} = t.times((videoSweepStartIdx{i}),3);
    
    ephysStartIdx{i} = floor(videoStartTime{i}*ephysSamplingRate) + 1;
    ephysTime{i} = (0:1:numel(v.voltage))/ephysSamplingRate;
    
    numSweeps{i} = numSweepsVideo;
    sweepNums{i} = 1:numSweeps{i};
    videoSweepStarts{i} = 1:videoFrameRate*sweepLengthInSec:(numSweeps{i}-1)*videoFrameRate*sweepLengthInSec+1;
    videoSweepEnds{i} = sweepLengthInSec*videoFrameRate*(1:1:numSweeps{i});
    
    % In timings file, grab time elapsed after each sweep starts/ends
    actualTimeElapsedStart{i} = shiftdim(t.times(videoSweepStarts{i},2) - t.times(videoSweepStarts{i}(1),2));
    appxTimeElapsedStart{i} = shiftdim(sweepLengthInSec*(0:1:numSweeps{i}-1));
    actualTimeElapsedEnd{i} = shiftdim(t.times(videoSweepEnds{i},2) - t.times(videoSweepStarts{i}(1),2));
    appxTimeElapsedEnd{i} = shiftdim(sweepLengthInSec*(1:1:numSweeps{i}));
    
    % Cut ephys by time elapsed after each sweep (variable number of
    % samples per sweep - maybe other issues to correct further down the line)
    % pre-allocate for parallel loop speed
    e = ephysTime{i};
    actStart =actualTimeElapsedStart{i};
    actEnd = actualTimeElapsedEnd{i};
    tempStartTimes = zeros(1,numSweeps{i});
    tempStartIdx = zeros(1,numSweeps{i});
    tempEndTimes = zeros(1,numSweeps{i});
    tempEndIdx = zeros(1,numSweeps{i});
    for j = 1:numSweeps{i}
        tempStart = actStart(j);
        tempEnd = actEnd(j);
        [~,tempIdx] = min(abs(e - tempStart));
        tempStartTimes(j) = e(tempIdx);
        tempStartIdx(j) = tempIdx;
        [~,tempIdx] = min(abs(e - tempEnd));
        tempEndTimes(j) = e(tempIdx);
        tempEndIdx(j) = tempIdx;
    end
    sweepStartIdx{i} = tempStartIdx;
    sweepStartTimes{i} = tempStartTimes;
    sweepEndIdx{i} = tempEndIdx;
    sweepEndTimes{i} = tempEndTimes;
    ephysEndIdx{i} = tempEndIdx(end) + ephysStartIdx{i} - 1;
end
toc

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
        session.sweepTimeInSec(ephysTrialNum) = sweepEndTimes{i}(n) - sweepStartTimes{i}(n);
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

%% Write video files
% Reads video frames sequentially and writes new 5-second long MP4 files
cd(mainFolder)
clearvars -except numSweeps timingFile videoFile numFramesPerSweep recID mainFolder
trialNum = 1;
for i = 1:numel(timingFile)
    t = load(timingFile{i});
%     v = load(voltageFile{i});
    % Cut video into sweeps
%     videoFReader = vision.VideoFileReader(videoFile{i});
    videoFReader = VideoReader(videoFile{i},'CurrentTime',0);
    videoCounter = 1;
    frameEnd = numSweeps{i}*numFramesPerSweep;
    for f = 1:frameEnd
        if videoCounter==1
            tic
            newFileName = [recID '_trialNum' num2str(trialNum) '.mp4'];
%             videoFWriter = vision.VideoFileWriter(newFileName, ...
%                 'FileFormat', 'MPEG4', 'Quality', 100);
            videoFWriter = VideoWriter(newFileName,'MPEG-4');
%             videoFWriter = VideoWriter(newFileName,'Motion JPEG AVI');
            videoFWriter.Quality=100;
            videoFWriter.FrameRate = 25;
            pause(0.1)
            open(videoFWriter)
        end
        
%         videoFrame = videoFReader();
%         videoFrame = flip(videoFrame,1);
%         videoFWriter(rgb2gray(videoFrame));

        videoFrame = readFrame(videoFReader);
        videoFrame = flip(videoFrame,1);
        writeVideo(videoFWriter,videoFrame);
        
        if videoCounter ~= numFramesPerSweep
            videoCounter = videoCounter + 1;
        elseif videoCounter==numFramesPerSweep
%             release(videoFWriter);
            close(videoFWriter);
            pause(0.1)
            disp(num2str(trialNum));
            videoCounter = 1;
            trialNum = trialNum + 1;
            toc
        end
    end
%     release(videoFReader);
    disp(num2str(videoCounter));
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


