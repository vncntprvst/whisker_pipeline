sessionDir =cd;
dirListing=dir(sessionDir);

%% Create files
%list files to split
videoFiles=ListVideoFiles(sessionDir);

% list timestamps files
timestampFiles=ListTSFiles(sessionDir);

% get and save whiskerpad coordinates
firstVideo=VideoReader(videoFiles(1).name);

[whiskingParams,splitUp]=WhiskingFun.DrawWhiskerPadROI(firstVideo);

if ~isfolder('WhiskerTracking')
    mkdir('WhiskerTracking');
end

WhiskingFun.SaveWhiskingParams(whiskingParams,fullfile(sessionDir,'WhiskerTracking'))

% Write Frame Split Index File
[frameTimes,frameTimeInterval] = CreateVideoTimeSplitFile(videoFiles,timestampFiles);
frameTimes = frameTimes-frameTimes(1);
frameRate=1/frameTimeInterval;
FRratio=frameRate/firstVideo.FrameRate;

%% Cut videos in 5 seconds chunks
for fileNum=1:numel(videoFiles)
    videoFileName=videoFiles(fileNum).name;
    frameSplitIndexFileName = [videoFileName(1:end-4) '_VideoFrameSplitIndex.csv'];
    videoDirectory=[sessionDir filesep];
    
    %% use openCV through python (works but too slow, because Matlab can't serialize Python objects in parfor)
    
    %     fps=int32(videoData.get(py.cv2.CAP_PROP_FPS));
    % %     videoData.get(py.cv2.CAP_PROP_FRAME_HEIGHT)
    %     codecType=int32(videoData.get(py.cv2.CAP_PROP_FOURCC));
    % %     py.cv2.VideoWriter_fourcc('a','0','0','0') %a\0\0\0
    %     fourCC=877677894; %(py.cv2.VideoWriter_fourcc('F','M','P','4'));
    %     apiPreference=int32(videoData.get(py.cv2.CAP_FFMPEG));
    % %     apiPreference 0 (cv2.CAP_ANY)  1900 (cv2.CAP_FFMPEG)
    % %     videoData.release()
    % %     foo='D:\Vincent\vIRt42\vIRt42_1016\WhiskerTracking\vIRt42_1016_4800_10Hz_10ms_10mW_20191016-121733_HSCam_Trial16.avi'
    % %     videoCap = py.cv2.VideoCapture(foo)
    %     videoOutDirectory=['D:\Vincent\vIRt42\vIRt42_1016\WhiskerTracking\'];
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
    BonsaiWFPath='V:\Code\BonsaiWorkFlows\VideoOp\';
     %'D:\Vincent\vIRt42\vIRt42_1016\';
    % C:\Users\wanglab\AppData\Local\Bonsai\Bonsai64.exe V:\Code\BonsaiWorkFlows\SplitVideoByFrameIndex.bonsai --start -p:Path.CSVFileName=VideoFrameSplitIndex.csv -p:Path.Directory=D:\Vincent\vIRt42\vIRt42_1016\ -p:Path.VideoFileName=vIRt42_1016_4800_10Hz_10ms_10mW_20191016-121733_HSCam.avi --start --noeditor
    switch splitUp
        case 'No'
            sysCall=[BonsaiPath 'Bonsai64.exe ' BonsaiWFPath 'SplitVideoByFrameIndex.bonsai'...
                ' -p:Path.CSVFileName=' frameSplitIndexFileName...
                ' -p:Path.Directory=' videoDirectory...
                ' -p:Path.VideoFileName=' videoFileName...
                ' --start --noeditor'];    
            disp(sysCall); system(sysCall);
        case 'Yes'
            sysCall=[BonsaiPath 'Bonsai64.exe ' BonsaiWFPath 'SplitVideoByFrameIndex_SplitLeft.bonsai'...
                ' -p:Path.CSVFileName=' frameSplitIndexFileName...
                ' -p:Path.Directory=' videoDirectory...
                ' -p:Path.VideoFileName=' videoFileName...
                ' --start --noeditor'];
            disp(sysCall); system(sysCall);
            sysCall=[BonsaiPath 'Bonsai64.exe ' BonsaiWFPath 'SplitVideoByFrameIndex_SplitRight.bonsai'...
                ' -p:Path.CSVFileName=' frameSplitIndexFileName...
                ' -p:Path.Directory=' videoDirectory...
                ' -p:Path.VideoFileName=' videoFileName...
                ' --start --noeditor'];
            disp(sysCall); system(sysCall);
    end
    
%             % check frame number
%         vf=[outputDir filesep 'vIRt50_1021_4736_20201021-194603_HSCam_Trial0.avi'];
%         videoData = py.cv2.VideoCapture(vf);
%         chunkFrameNum=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT);

    %% use ffmpeg + [optional] Split video in two vertically
%     splitIndex=load(frameSplitIndexFileName);
%     splitIndex=splitIndex+1; % 1 index
%     outputDir = fullfile(videoDirectory, 'WhiskerTracking');
%     
%     for chunkNum=1:size(splitIndex,1)
%         sysCall=['ffmpeg -y -r ' num2str(frameRate) ' -i ' videoFileName ' -ss ' ...
%             num2str(floor(frameTimes(splitIndex(chunkNum,1))*FRratio)) ' -to '...
%             num2str(floor(frameTimes(splitIndex(chunkNum,2)+1)*FRratio)) ...
%             ' -c:v copy -c:a copy -r ' num2str(frameRate) ' '...
%             outputDir filesep videoFileName(1:end-4) '_Trial' ...
%             num2str(chunkNum-1) '.mp4' ' -async 1 ' ...
%             ' -hide_banner -loglevel panic'];
%         disp(sysCall); system(sysCall);
%         
%         
%         % check frame number
%         vf=[outputDir filesep videoFileName(1:end-4) '_Trial' num2str(chunkNum-1) '.mp4'];
%         videoData = py.cv2.VideoCapture(vf);
%         chunkFrameNum=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT);
%         
%         switch splitUp
%             case 'No'
%             case 'Yes'
%                 outF=[outputDir filesep videoFileName(1:end-4) '_Trial' num2str(chunkNum-1) '.mp4'];
%                 sysCall=['ffmpeg -y -i ' outF ...
%                     ' -vf crop=' num2str(midWidth) ':' num2str(size(vidFrame,1)) ':0:0 ' ...
%                     '-c:a copy '...
%                     outputDir filesep videoFileName(1:end-4) '_LeftW_Trial' ...
%                     num2str(chunkNum-1) '.mp4'];
%                 disp(sysCall); system(sysCall);
%                 
%                 sysCall=['ffmpeg -y -i ' outF ...
%                     ' -vf crop=' num2str(midWidth) ':' num2str(size(vidFrame,1))...
%                     ':' num2str(midWidth) ':0 ' ...
%                     '-c:a copy '...
%                     outputDir filesep videoFileName(1:end-4) '_RightW_Trial' ...
%                     num2str(chunkNum-1) '.mp4'];
%                 disp(sysCall); system(sysCall);
%                 
%                 % check frame number
%                 vf=[outputDir filesep videoFileName(1:end-4) '_Right_Trial' num2str(chunkNum-1) '.mp4'];
%                 videoData = py.cv2.VideoCapture(outF);
%                 splitChunkFrameNum=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT)
%                 if chunkFrameNum~=splitChunkFrameNum
%                     disp('inconsistant frame number after split')
%                 end
%         end
%     end
end

% [optional] If need to convert avi files to mp4
cd([sessionDir filesep 'WhiskerTracking'])
aviFiles = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
    {'*.avi'},'UniformOutput', false);
aviFiles=vertcat(aviFiles{~cellfun('isempty',aviFiles)});

if ~isempty(aviFiles)
    for fileNum=1:numel(aviFiles)
        sysCall=['ffmpeg -i ' aviFiles(fileNum).name ' -vcodec copy ' aviFiles(fileNum).name(1:end-3) 'mp4'];
        disp(sysCall); system(sysCall);
    end
	delete *.avi
end

% cd ..

%% Perform whisker detection
%Command line references: http://whiskertracking.janelia.org/wiki/display/MyersLab/Whisker+Tracking+Command+Line+Reference
% list files
% cd([sessionDir filesep 'WhiskerTracking'])
ext = '.mp4';
ignoreExt = '.measurements';
for wpNum=1:numel(whiskingParams)
    include_files = arrayfun(@(x) x.name(1:(end-length(ext))),...
        dir([sessionDir filesep 'WhiskerTracking' filesep '*' ext]),'UniformOutput',false);
    % Return list of files that are already tracked
    ignore_files = arrayfun(@(x) x.name(1:(end-length(ignoreExt))),...
        dir([sessionDir filesep 'WhiskerTracking' filesep '*' ignoreExt]),'UniformOutput',false); 
    switch splitUp
        case 'Yes' 
            switch whiskingParams(wpNum).FaceSideInImage
                case 'right'
                    keepLabel = 'Left';
                case 'left'
                    keepLabel = 'Right';
            end
            keepFile=logical(cellfun(@(fName) contains(fName,keepLabel,...
                'IgnoreCase',true), include_files));
        case 'No'
            keepFile = true(size(include_files));
    end
    inclusionIndex = ~ismember(include_files,ignore_files) & keepFile;
    include_files = include_files(inclusionIndex);

    % initialize parameters
    num_whiskers = 3; %-1 %10;

    % process all files
    if numel(whiskingParams)>1 %large FOV covering both sides of the head
        px2mm = 0.1;
    else
        px2mm = 0.05; %normal close up view of one side of the head
    end
    Whisker.makeAllDirectory_Tracking([sessionDir filesep 'WhiskerTracking'],'ext',ext,...
        'include_files',include_files,'side',whiskingParams(wpNum).FaceSideInImage,...
        'face_x_y',whiskingParams(wpNum).Location,'px2mm',px2mm,'num_whiskers',num_whiskers);

end
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

%% Then concatenate with BindMeasurements
if strcmp(regexp(cd,['(?<=\' filesep ')\w+$'],'match','once'),'WhiskerTracking')
    cd ..
end
sessionDir = cd;
SaveWhiskerData(sessionDir);

%% Test performence with one trial
if false
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
        filePath = fullfile(sessionDir, 'WhiskerTracking', [fileName '.measurements']); %'D:\Vincent\vIRt43\vIRt43_1204\WhiskerTracking\vIRt43_1204_4400_20191204-171925_HSCam_Trial0.measurements';
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
    mw = ManyWhiskers([sessionDir filesep 'WhiskerTracking'], ...
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
        syscall = ['C:\Progra~1\WhiskerTracking\bin\measure --face ' num2str(whiskerPadLocation)...
            ' x  ' fileName '.whiskers ' fileName '.measurements']; disp(syscall); system(syscall);
        syscall = ['C:\Progra~1\WhiskerTracking\bin\classify ' fileName '.measurements ' ...
            fileName '.measurements ' num2str(whiskerPadLocation) ' x --px2mm 0.064 -n ' ...
            num2str(num_whiskers) ' --limit2.0:50.0']; %--limit2.0:50.0'
        disp(syscall); system(syscall);
        sysCall = ['C:\Progra~1\WhiskerTracking\bin\reclassify -n ' num2str(num_whiskers)...
            ' ' include_files{fileNum} '.measurements ' include_files{fileNum} '.measurements'];
        disp(sysCall);
        system(sysCall);
    end
    
    % Using Whisker linker
    for fileNum=1:numel(include_files)
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
    
    %Plot input
    dt=0.002;
    time=double([linkedMeasurements.measurements(:).fid]).*dt;
    angle=[linkedMeasurements.measurements(:).angle];
    colors=['r','g','b','k','c','m'];
    figure;clf;
    hold on;
    for whisker_id=1%:max([linkedMeasurements.measurements(:).label])
        mask = [linkedMeasurements.measurements(:).label]==whisker_id;
        plot(time(mask),angle(mask),colors(whisker_id+1));
    end
    
    %Plot output
    dt=0.002;
    time=double([linkedMeasurements.outMeasurements(:).fid]).*dt;
    angle=[linkedMeasurements.outMeasurements(:).angle];
    colors=['r','g','b','k','c','m'];
    figure;clf;
    hold on;
    for whisker_id=0%:max([linkedMeasurements.outMeasurements(:).label])
        mask = [linkedMeasurements.outMeasurements(:).label]==whisker_id;
        plot(time(mask),angle(mask),colors(whisker_id+1));
    end
    
end

%% functions
function videoFiles=ListVideoFiles(sessionDir)
videoFiles = cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),...
    {'*.mp4','*.avi'},'UniformOutput', false);
videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
videoFiles=videoFiles(~cellfun(@(flnm) contains(flnm,{'webcam';'Webcam'}),...
    {videoFiles.name})); % by folder name
end

function timestampFiles=ListTSFiles(sessionDir)
timestampFiles=cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),... %'**' filesep
    {'*.dat','*.csv'},'UniformOutput', false);
timestampFiles=vertcat(timestampFiles{~cellfun('isempty',timestampFiles)});
timestampFiles=timestampFiles(cellfun(@(flnm) contains(flnm,{'_VideoFrameTimes','vSync'}),...
    {timestampFiles.name}));
if isempty(timestampFiles) %No TTL based timestamps, or not exported yet.
    timestampFilesIndex=cellfun(@(fileName) contains(fileName,{'HSCamFrameTime.csv'; ...
        'HSCam.csv';'HSCam_Parsed.csv';'tsbackup'}),{dirListing.name},'UniformOutput', true);
    timestampFiles=dirListing(timestampFilesIndex);
end
end
