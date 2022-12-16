function CutVideos(sessionDir,videoFiles,overWrite)

if nargin < 3; overWrite=false; end

% If videos already cut, skip
if ~overWrite
    wtDirList=dir(fullfile(sessionDir,'WhiskerTracking'));
    wtDirVids={wtDirList(cellfun(@(wtFN) contains(wtFN,{'mp4','avi'}),{wtDirList.name})).name};
    videoFiles=videoFiles(~cellfun(@(vidF) any(contains(wtDirVids,vidF(1:end-4))), {videoFiles.name}));
end

if ~isempty(videoFiles)

    [whiskingParams,splitUp]=GetWhiskingParams(sessionDir,videoFiles);

    % Write Frame Split Index File
    timestampFiles=ListTSFiles(sessionDir);
    [~,frameRate] = CreateVideoTimeSplitFile(videoFiles,timestampFiles,cd,false);

    if ~system('ffmpeg -version') % use ffmpeg
        use_ffmpeg=true;
    elseif ~system('Bonsai --noeditor') % use Bonsai
        use_bonsai=true;
    elseif contains(class(py.cv2.VideoCapture),'py.cv2.VideoCapture') % use CV2
        use_cv2=true;
    end

    for fileNum=1:numel(videoFiles)
        videoFileName=videoFiles(fileNum).name;
        videoDirectory=[sessionDir filesep];
        outputDir = fullfile(videoDirectory, 'WhiskerTracking');

        % Split video file + [optional] Split video in two vertically
        if use_ffmpeg
            FFMPEG_Split(videoFileName,frameRate,outputDir,whiskingParams,splitUp);
        elseif use_bonsai
            frameSplitIndexFileName = [videoFileName(1:end-4) '_VideoFrameSplitIndex.csv'];
            Bonsai_Split(videoDirectory,videoFileName,sessionDir,frameSplitIndexFileName,frameRate)
        elseif use_cv2
            pyCV2_Split(videoData,chunkIndex)
        end        
    end

    % [optional] If need to convert avi files to mp4
    cd([sessionDir filesep 'WhiskerTracking'])
    aviFiles = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
        {'*.avi'},'UniformOutput', false);
    aviFiles=vertcat(aviFiles{~cellfun('isempty',aviFiles)});
    if ~isempty(aviFiles)
        ConvAVI2MP4(aviFiles)
    end
end

end

%% Nested functions
function FFMPEG_Split(videoFileName,frameRate,outputDir,whiskingParams,splitUp)
%             outF=[outputDir filesep videoFileName(1:end-4) '_Trial' num2str(chunkNum-1) '.mp4'];

inputArg=['ffmpeg -y -hwaccel_output_format cuda -r ' num2str(frameRate{1}) ' -i ' videoFileName];
encodeArg=['  -f segment -segment_time 100 '...
            '-c:v copy -c:a copy -reset_timestamps 1 -map 0:0 -r ' num2str(frameRate{1})];
ouputArg=['-an ' outputDir filesep videoFileName(1:end-4)];
logArg=' -async 1 -hide_banner -loglevel panic';

switch splitUp

    case 'No'
    ouputArg=[ouputArg '_Trial%d.mp4'];
    sysCall=[inputArg encodeArg ouputArg logArg];

    case 'Yes'
        vidFrame=whiskingParams(1).ImageDimensions;
        splitLArg=[' -vf crop=' num2str(vidFrame(2)) ':' num2str(vidFrame(1)) ':0:0 '];
        splitRArg=[' -vf crop=' num2str(vidFrame(2)) ':' num2str(vidFrame(1)) ':' num2str(vidFrame(2)) ':0 '];

        sysCall=[inputArg ...
            encodeArg splitLArg ouputArg '_Left_Trial%d.mp4' ...
            encodeArg splitRArg ouputArg '_Right_Trial%d.mp4'...
            logArg];

% 
%         sysCall=['ffmpeg -y -i ' outF ...
%             ' -vf crop=' num2str(midWidth) ':' num2str(size(vidFrame,1)) ':0:0 ' ...
%             '-c:a copy '...
%             outputDir filesep videoFileName(1:end-4) '_Left_Trial' ...
%             num2str(chunkNum-1) '.mp4'];
%         disp(sysCall); system(sysCall);
% 
%         sysCall=['ffmpeg -y -i ' outF ...
%             ' -vf crop=' num2str(midWidth) ':' num2str(size(vidFrame,1))...
%             ':' num2str(midWidth) ':0 ' ...
%             '-c:a copy '...
%             outputDir filesep videoFileName(1:end-4) '_Right_Trial' ...
%             num2str(chunkNum-1) '.mp4'];
%         disp(sysCall); system(sysCall);

        % check frame number
%         vf=[outputDir filesep videoFileName(1:end-4) '_Right_Trial' num2str(chunkNum-1) '.mp4'];
%         CheckFrameNum(vf,chunkFrameNum)
end

        disp(sysCall); system(sysCall);

% % Get Frame Rate ratio
% % firstVideo=VideoReader(videoFiles(1).name);
% % videoFrameRate=firstVideo.FrameRate;
% % clearvars firstVideo
%  [~,videoFrameRate]=system(['ffprobe -v 0 -of csv=p=0 -select_streams v:0'...
% ' -show_entries stream=r_frame_rate ' videoFiles(1).name]);
% FRratio=frameRate{1}/videoFrameRate;

%     sysCall=['ffmpeg -y -r ' num2str(frameRate) ' -i ' videoFileName ' -ss ' ...
%         num2str(floor(frameTimes(splitIndex(chunkNum,1))*FRratio)) ' -to '...
%         num2str(floor(frameTimes(splitIndex(chunkNum,2)+1)*FRratio)) ...
%         ' -c:v copy -c:a copy -r ' num2str(frameRate) ' '...
%         outputDir filesep videoFileName(1:end-4) '_Trial' ...
%         num2str(chunkNum-1) '.mp4' ' -async 1 ' ...
%         ' -hide_banner -loglevel panic'];
%     disp(sysCall); system(sysCall);
%
%

end


function Bonsai_Split(videoDirectory,videoFileName,sessionDir,frameSplitIndexFileName)
% use Bonsai if installed
%     if ~system('Bonsai --noeditor') % found in the path
BonsaiPath=''; % no need to set the path then
%     else % assume default install location on Windows
%         BonsaiPath=['C:\Users\' lower(getenv('username')) '\AppData\Local\Bonsai\'];
%         if ~exist(BonsaiPath,'dir') %no luck finding it
%             clearvars BonsaiPath
%         end
%     end

BonsaiWFPath=fullfile(fileparts(mfilename('fullpath')),'VideoOp');
trialNum=size(readmatrix(frameSplitIndexFileName),1);
splitIndex=readmatrix(frameSplitIndexFileName);
splitIndex=splitIndex+1; % 1 index

for chunkNum=1:size(splitIndex,1)

callFlags= [' -p:Path.CSVFileName=' frameSplitIndexFileName...
    ' -p:Path.Directory=' videoDirectory...
    ' -p:Path.VideoFileName=' videoFileName...
    ' --start --noeditor'];
wtDirList=dir(fullfile(sessionDir,'WhiskerTracking'));
wtDirMes={wtDirList(cellfun(@(wtFN) contains(wtFN,{'.measurements'}),{wtDirList.name})).name};
switch splitUp
    case 'No'
        mesFiles=wtDirMes(cellfun(@(x) contains(x,videoFileName(1:end-4)) ,wtDirMes));
        if numel(mesFiles)<trialNum || (islogical(overWrite) && overWrite)
            BonsaiWFPath=fullfile(BonsaiWFPath, 'SplitVideoByFrameIndex.bonsai');
            sysCall=[BonsaiPath 'Bonsai ' BonsaiWFPath callFlags];
            disp(sysCall); [~,~]= system(sysCall);
        end
    case 'Yes'
        leftMesFiles=wtDirMes(cellfun(@(x) contains(x,[videoFileName(1:end-4),'_Left']) ,wtDirMes));
        if numel(leftMesFiles)<trialNum || (islogical(overWrite) && overWrite)
            BonsaiWFPath=fullfile(BonsaiWFPath, 'SplitVideoByFrameIndex_SplitLeft.bonsai');
            sysCall=[BonsaiPath 'Bonsai ' BonsaiWFPath callFlags];
            disp(sysCall); [~,~]= system(sysCall);
        end
        rightMesFiles=wtDirMes(cellfun(@(x) contains(x,[videoFileName(1:end-4),'_Right']) ,wtDirMes));
        if numel(rightMesFiles)<trialNum || (islogical(overWrite) && overWrite)
            BonsaiWFPath=fullfile(BonsaiWFPath, 'SplitVideoByFrameIndex_SplitRight.bonsai');
            sysCall=[BonsaiPath 'Bonsai ' BonsaiWFPath callFlags];
            disp(sysCall); [~,~]= system(sysCall);
        end
end
end
end

function pyCV2_Split(videoData,chunkIndex)
%% then use openCV through python (works but too slow, because Matlab can't serialize Python objects in parfor)
fps=int32(videoData.get(py.cv2.CAP_PROP_FPS));
%     videoData.get(py.cv2.CAP_PROP_FRAME_HEIGHT)
codecType=int32(videoData.get(py.cv2.CAP_PROP_FOURCC));
%     py.cv2.VideoWriter_fourcc('a','0','0','0') %a\0\0\0
fourCC=877677894; %(py.cv2.VideoWriter_fourcc('F','M','P','4'));
apiPreference=int32(videoData.get(py.cv2.CAP_FFMPEG));
%     apiPreference 0 (cv2.CAP_ANY)  1900 (cv2.CAP_FFMPEG)
%     videoData.release()
%     videoCap = py.cv2.VideoCapture(foo)
%         videoOutDirectory=''; fix this
for chunkNum=1:size(chunkIndex,1)
    videoOutFileName=[videoFileName(1:end-4) '_Trial' num2str(chunkNum) '.mp4'];
    videoOut=py.cv2.VideoWriter;
    %         writer = py.cv2.VideoWriter
    %         videoOut.open('test1.avi',int32(1900),int32(fourCC),25,py.tuple({int32(640),int32(480)}))
    %         videoOut.open(fullfile(videoOutDirectory,videoOutFileName),apiPreference,codecType,fps,py.tuple({int32(640),int32(480)}))
    videoOut.open(fullfile(videoOutDirectory,videoOutFileName),...
        int32(1900),int32(fourCC),fps,py.tuple({int32(640),int32(480)}));
    %,int32([640,480])); %
    %             "FMP4", 500,
    for frameNum=(chunkIndex(chunkNum,1):chunkIndex(chunkNum,2)-1)-1
        videoData.set(py.cv2.CAP_PROP_POS_FRAMES,frameNum);
        frameData=videoData.read();
        videoOut.write(frameData{2})
    end
    %     cv2.imwrite(w_path,frame)
    videoOut.release()
end
videoData.release()
end

function ConvAVI2MP4(aviFiles)
for fileNum=1:numel(aviFiles)
    if ~exist([aviFiles(fileNum).name(1:end-3) 'mp4'],'file')
        sysCall=['ffmpeg -i ' aviFiles(fileNum).name ' -vcodec copy ' aviFiles(fileNum).name(1:end-3) 'mp4'];
        disp(sysCall); system(sysCall);
    end
end
delete *.avi
end

function timestampFiles=ListTSFiles(sessionDir)
timestampFiles=cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),... %'**' filesep
    {'*.dat','*.csv'},'UniformOutput', false);
timestampFiles=vertcat(timestampFiles{~cellfun('isempty',timestampFiles)});
timestampFiles=timestampFiles(cellfun(@(flnm) contains(flnm,{'_VideoFrameTimes','vSync'}),...
    {timestampFiles.name}));
if isempty(timestampFiles) %No TTL based timestamps, or not exported yet.
    dirListing=dir(sessionDir);
    timestampFilesIndex=cellfun(@(fileName) contains(fileName,{'HSCamFrameTime.csv'; ...
        'HSCam.csv';'HSCam_Parsed.csv';'tsbackup'}),{dirListing.name},'UniformOutput', true);
    timestampFiles=dirListing(timestampFilesIndex);
end
end

function CheckFrameNum(vf,chunkFrameNum)
        videoData = py.cv2.VideoCapture(vf);
        splitChunkFrameNum=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT);
        if chunkFrameNum~=splitChunkFrameNum
            disp('inconsistant frame number after split')
        end
end