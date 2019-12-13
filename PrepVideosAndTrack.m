sessionDir =cd; %'D:\Vincent\vIRt43\vIRt43_1204' ;% 'D:\Vincent\vIRt41\vIRt41_0808'; %'D:\Vincent\vIRt42\vIRt42_1016';
dirListing=dir(sessionDir);

%% Create files
%list files to split (specify avi or mp4)
videoFiles = cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),...
    {'*.mp4','*.avi'},'UniformOutput', false);
videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
% list timestamps files
timestampFilesIndex=cellfun(@(fileName) contains(fileName,'HSCamFrameTime.csv')==1,...
    {dirListing.name},'UniformOutput', true);
timestampFiles={dirListing(timestampFilesIndex).name};

% get whiskerpad coordinates
firstVideo=VideoReader(videoFiles(1).name);
vidFrame = readFrame(firstVideo);
figure; image(vidFrame);
whiskerPadCoordinates = drawrectangle;
whiskerPadCoordinates = whiskerPadCoordinates.Position;
close(gcf); clearvars firstVideo

% Cut videos in 5 seconds chunks 
for fileNum=1:numel(videoFiles)
    clearvars videoData numFrames compIndex videoTimestamps
    videoFileName=videoFiles(fileNum).name;
    videoData = py.cv2.VideoCapture(videoFileName);
    numFrames=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT);
    % find corresponding csv file, comparing with video file name (they
    % might not be exactly the same, to due timestamp in filename)
    if ~isempty(timestampFiles)
    for strCompLength=numel(videoFileName):-1:1
        compIndex=cellfun(@(fileName) strncmpi([videoFileName(1:end-4) 'FrameTime.csv'],fileName,strCompLength),...
            timestampFiles);
        if sum(compIndex)==1 %found it
            break
        end
    end
    videoTimestampFile=timestampFiles{compIndex};
    % read timestamps
    videoTimestamps=readtable(videoTimestampFile);        
    % If needed, double check TTLs too: 
%         [~,~,~,TTLs] =LoadEphysData('vIRt42_1016_4800_10Hz_10ms_10mW.ns6',cd);
%         triggerTimes=TTLs{1, 2}.TTLtimes/TTLs{1, 2}.samplingRate*1000;triggerTimes=triggerTimes'-triggerTimes(1);
%         videoTimestamps=videoTimestamps.RelativeCameraFrameTime; %RelativeSoftwareFrameTime; %RelativeCameraFrameTime
%         frameTimes=videoTimestamps/10^6;
%         figure; plot(diff([triggerTimes';frameTimes']))
    else
        videoTimestamps=table(linspace(1,numFrames*2,numFrames)','VariableNames',{'Var1'});
    end
    % check that video has as many frames as timestamps
    if size(videoTimestamps,1)~=numFrames
        disp(['discrepancy in frame number for file ' videoFileName])
        continue
    else %do the splitting
        chunkDuration=5; % duration of chunks in seconds
        %Based on Timestamp (unfortunately, Basler cam clocks are not reliable)
%         videoTimestamps=videoTimestamps.RelativeCameraFrameTime;
%         chunkIndex=find([0;diff(mod(videoTimestamps/10^9,chunkDuration))]<0); % find the 5 second video segments
%         %make 2 columns: start and stop indices
%         chunkIndex=int32([1,chunkIndex(1,1);chunkIndex(1:end-1),chunkIndex(2:end)]);
        % Just based on time
        if ismember('RelativeCameraFrameTime', videoTimestamps.Properties.VariableNames)
            frameTimeInterval=unique(round(diff(videoTimestamps.RelativeCameraFrameTime/10^6))); %in ms
        else
            frameTimeInterval=round(mean(diff(videoTimestamps.Var1)));
        end
        chunkIndex=0:chunkDuration*1000/frameTimeInterval:numFrames;
        chunkIndex=int32([chunkIndex(1:end-1)',chunkIndex(2:end)'-1]);
        % write the file
        frameSplitIndexFileName=[videoFileName(1:end-4) '_VideoFrameSplitIndex.csv'];
        dlmwrite([sessionDir filesep frameSplitIndexFileName],chunkIndex,'delimiter', ',','precision','%i');
        %% use openCV through python (works but too slow, because Matlab can't serialize Python objects in parfor)
        
        %     fps=int32(videoData.get(py.cv2.CAP_PROP_FPS));
        % %     videoData.get(py.cv2.CAP_PROP_FRAME_HEIGHT)
        %     codecType=int32(videoData.get(py.cv2.CAP_PROP_FOURCC));
        % %     py.cv2.VideoWriter_fourcc('a','0','0','0') %a\0\0\0
        %     fourCC=877677894; %(py.cv2.VideoWriter_fourcc('F','M','P','4'));
        %     apiPreference=int32(videoData.get(py.cv2.CAP_FFMPEG));
        % %     apiPreference 0 (cv2.CAP_ANY)  1900 (cv2.CAP_FFMPEG)
        % %     videoData.release()
        % %     foo='D:\Vincent\vIRt42\vIRt42_1016\workspace\vIRt42_1016_4800_10Hz_10ms_10mW_20191016-121733_HSCam_Trial16.avi'
        % %     videoCap = py.cv2.VideoCapture(foo)
        %     videoOutDirectory=['D:\Vincent\vIRt42\vIRt42_1016\workspace\'];
        %     for chunkNum=1:size(chunkIndex,1)
        %         videoOutFileName=[videoFileName(1:end-4) '_Trial' num2str(chunkNum) '.mp4'];
        %         videoOut=py.cv2.VideoWriter;
        % %         writer = py.cv2.VideoWriter
        % %         videoOut.open('test1.avi',int32(1900),int32(fourCC),25,py.tuple({int32(640),int32(480)}))
        % %         videoOut.open(fullfile(videoOutDirectory,videoOutFileName),apiPreference,codecType,fps,py.tuple({int32(640),int32(480)}))
        %         videoOut.open(fullfile(videoOutDirectory,videoOutFileName),...
        %             int32(1900),int32(fourCC),fps,py.tuple({int32(640),int32(480)}));
        %         %,int32([640,480])); %
        % %             "FMP4", 500,
        %         for frameNum=(chunkIndex(chunkNum,1):chunkIndex(chunkNum,2)-1)-1
        %             videoData.set(py.cv2.CAP_PROP_POS_FRAMES,frameNum);
        %             frameData=videoData.read();
        %             videoOut.write(frameData{2})
        %         end
        % %     cv2.imwrite(w_path,frame)
        %         videoOut.release()
        %     end
        %     videoData.release()
        
        %% use Bonsai:
        BonsaiPath='C:\Users\wanglab\AppData\Local\Bonsai\';
        BonsaiWFPath='V:\Code\BonsaiWorkFlows\';
        videoDirectory=[sessionDir filesep]; %'D:\Vincent\vIRt42\vIRt42_1016\';
        % C:\Users\wanglab\AppData\Local\Bonsai\Bonsai64.exe V:\Code\BonsaiWorkFlows\SplitVideoByFrameIndex.bonsai --start -p:Path.CSVFileName=VideoFrameSplitIndex.csv -p:Path.Directory=D:\Vincent\vIRt42\vIRt42_1016\ -p:Path.VideoFileName=vIRt42_1016_4800_10Hz_10ms_10mW_20191016-121733_HSCam.avi --start --noeditor
        sysCall=[BonsaiPath 'Bonsai64.exe ' BonsaiWFPath 'SplitVideoByFrameIndex.bonsai'...
            ' -p:Path.CSVFileName=' frameSplitIndexFileName...
            ' -p:Path.Directory=' videoDirectory...
            ' -p:Path.VideoFileName=' videoFileName...
            ' --start --noeditor'];
        disp(sysCall);
        system(sysCall);
        
        %% use ffmpeg
        % see ChunkFile
        %         cmd = ['-y -i ' fn ' -ss ' startTime ' -to ' endTime ...
        %             ' -c:v copy -c:a copy ' outputLoc outputName '.mp4' ' -async 1 ' ...
        %             ' -hide_banner -loglevel panic'];
        %         disp(cmd);
        %         ffmpegexec(cmd);
    end
end

% [optional] If need to convert avi files to mp4
cd([sessionDir filesep 'workspace'])
aviFiles = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
    {'*.avi'},'UniformOutput', false);
aviFiles=vertcat(aviFiles{~cellfun('isempty',aviFiles)});

if ~isempty(aviFiles)
    for fileNum=1:numel(aviFiles)
        sysCall=['ffmpeg -i ' aviFiles(fileNum).name ' -vcodec copy ' aviFiles(fileNum).name(1:end-3) 'mp4'];
        disp(sysCall); system(sysCall);
        aviFiles(fileNum).name
    end
    delete *.avi
end
% cd ..

%% Perform whisker detection
%Command line references: http://whiskertracking.janelia.org/wiki/display/MyersLab/Whisker+Tracking+Command+Line+Reference
% list files
% cd([sessionDir filesep 'workspace'])
ext = '.mp4';
ignoreExt = '.measurements';
include_files = arrayfun(@(x) x.name(1:(end-length(ext))), dir([sessionDir filesep 'workspace' filesep '*' ext]),'UniformOutput',false);
ignore_files = arrayfun(@(x) x.name(1:(end-length(ignoreExt))), dir([sessionDir filesep 'workspace' filesep '*' ignoreExt]),'UniformOutput',false); % Returns list of files that are already tracked
c = setdiff(include_files,ignore_files);
disp(['Number of files detected :' numel(include_files)])
disp(['Number of files to ignore :' numel(ignore_files)])
disp(['Number of files included :' numel(c)])
include_files = c;

% initialize parameters
face_x_y = round([whiskerPadCoordinates(1)+whiskerPadCoordinates(3)/2,...
    whiskerPadCoordinates(2)+whiskerPadCoordinates(4)/2]); %[140 264]; 
num_whiskers = 3; %-1 %10; 

% all files
tic
Whisker.makeAllDirectory_Tracking([sessionDir filesep 'workspace'],'ext',ext,...
    'include_files',include_files,...
    'face_x_y',face_x_y,'num_whiskers',num_whiskers);
toc

% sanity check: single file
% fileNum=1;
% fileName=include_files{fileNum};
% syscall = ['C:\Progra~1\WhiskerTracking\bin\trace ' fileName ext ' ' fileName '.whiskers']; disp(syscall); system(syscall);
% syscall = ['C:\Progra~1\WhiskerTracking\bin\measure --face ' num2str(face_x_y)...
%     ' x  ' fileName '.whiskers ' fileName '.measurements']; disp(syscall); system(syscall);
% syscall = ['C:\Progra~1\WhiskerTracking\bin\classify ' fileName '.measurements ' ...
%     fileName '.measurements ' num2str(face_x_y) ' x --px2mm 0.064 -n ' ...
%     num2str(num_whiskers) ' --limit2.0:50.0']; %--limit2.0:50.0'
% disp(syscall); system(syscall);


%%%%%%%%%%%%%%%%%%%%%%%
%% Link measurements %%
%%%%%%%%%%%%%%%%%%%%%%%

% filePath = fullfile(sessionDir, 'workspace', [fileName '.measurements']); %'D:\Vincent\vIRt43\vIRt43_1204\workspace\vIRt43_1204_4400_20191204-171925_HSCam_Trial0.measurements'; 

%% Test performence with one trial 

% Initialize object
% ow = OneWhisker('path', filePath, 'silent', false, ...
%     'whiskerID', 0, ...
%     'distToFace', 30, ... % for face mask
%     'polyRoiInPix', [31 163], ... % point of interest on whisker close to pole 
%     'rInMm', 4.5, ... %point where curvature is measured
%     'whiskerRadiusAtBaseInMicron', 44, ... %post-hoc measurement   
%     'whiskerLengthInMm', 25.183, ...    %post-hoc measurement   
%     'faceSideInImage', 'top', ... 
%     'protractionDirection', 'leftward',...
%     'linkingDirection','rostral',...
%     'whiskerpadROI',whiskerPadCoordinates,...
%     'whiskerLengthThresh',50,...
%     'silent',true); % caudal or rostral

% Then link
% ow.LinkWhiskers('Force', true);            % see Guide for the detail about 'Force'

% Additional processing 
% ow.MakeMasks('Force', true);  
% ow.DetectBar('Force', true);  
% ow.DoPhysics('Force', true);  

%% Loop through session
for fileNum=1:numel(include_files)
    fileName=include_files{fileNum};
    filePath = fullfile(sessionDir, 'workspace', [fileName '.measurements']); %'D:\Vincent\vIRt43\vIRt43_1204\workspace\vIRt43_1204_4400_20191204-171925_HSCam_Trial0.measurements';
    ow = OneWhisker('path', filePath, 'silent', false, ...
        'whiskerID', 0, ...
        'distToFace', 30, ... % for face mask
        'polyRoiInPix', [31 163], ... % point of interest on whisker close to pole
        'rInMm', 4.5, ... %point where curvature is measured
        'whiskerRadiusAtBaseInMicron', 44, ... %post-hoc measurement
        'whiskerLengthInMm', 25.183, ...    %post-hoc measurement
        'faceSideInImage', 'top', ...
        'protractionDirection', 'leftward',...
        'linkingDirection','rostral',...
        'whiskerpadROI',whiskerPadCoordinates,...
        'whiskerLengthThresh',50,...
        'silent',true); % caudal or rostral
    
    % Link
    ow.LinkWhiskers('Force', true);            % see Guide for the detail about 'Force'
    
    % Save
    ow.objStruct.measurements.Save([include_files{fileNum} '_curated.measurements']);
end


%% Link whole session
if ~exist([sessionDir filesep 'settings'],'dir')
    mkdir([sessionDir filesep 'settings']);
end
mw = ManyWhiskers([sessionDir filesep 'workspace'], ...
    'sessionDictPath', [sessionDir filesep 'settings' filesep 'session_dictionary.xlsx'], ... % where session info are saved
    'sessionDictEntryIdx', NaN, ...
    'measurements', true,...
    'bar', false, ...
    'facemasks', false, ...
    'physics', false, ...
    'contact', false);

%% Other Linking methods
% Using Reclassify script
% Classify only 5 whiskers now
num_whiskers=3;
for fileNum=1:numel(include_files)
    syscall = ['C:\Progra~1\WhiskerTracking\bin\measure --face ' num2str(face_x_y)...
    ' x  ' fileName '.whiskers ' fileName '.measurements']; disp(syscall); system(syscall);
    syscall = ['C:\Progra~1\WhiskerTracking\bin\classify ' fileName '.measurements ' ...
        fileName '.measurements ' num2str(face_x_y) ' x --px2mm 0.064 -n ' ...
        num2str(num_whiskers) ' --limit2.0:50.0']; %--limit2.0:50.0'
    disp(syscall); system(syscall);
    sysCall = ['C:\Progra~1\WhiskerTracking\bin\reclassify -n ' num2str(num_whiskers)...
        ' ' include_files{fileNum} '.measurements ' include_files{fileNum} '.measurements'];
    disp(sysCall);
    system(sysCall);
end

% Using Whisker linker
for fileNum=353:numel(include_files)
    try
        %Load measurements
        measurementsPath=[include_files{fileNum} '.measurements'];
        trialMeasurements = Whisker.LoadMeasurements(measurementsPath);
        % Link across frames
        linkedMeasurements = WhiskerLinkerLite(trialMeasurements);
        %Save output
        Whisker.SaveMeasurements(measurementsPath,linkedMeasurements.outMeasurements);
    catch
    end
end

%Plot output
dt=0.002;
time=double([linkedMeasurements.outMeasurements(:).fid]).*dt;
angle=[linkedMeasurements.outMeasurements(:).angle];
colors=['r','g','b','k','c','m'];
figure;clf;
hold on;
for whisker_id=0:max([linkedMeasurements.outMeasurements(:).label])
    mask = [linkedMeasurements.outMeasurements(:).label]==whisker_id;
    plot(time(mask),angle(mask),colors(whisker_id+1));
end




