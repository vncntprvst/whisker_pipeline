function CutVideos(sessionDir,videoFiles)

%% Write Frame Split Index File
% list timestamps files
timestampFiles=ListTSFiles(sessionDir);

[frameTimes,frameTimeInterval] = CreateVideoTimeSplitFile(videoFiles,timestampFiles);
frameTimes = frameTimes-frameTimes(1);
frameRate=1/frameTimeInterval;
FRratio=frameRate/firstVideo.FrameRate;

%% Split videos
% use Bonsai if installed
if ~system('Bonsai --noeditor') % found in the path
    BonsaiPath=''; % no need to set the path then
else % assume default install location on Windows
    BonsaiPath=['C:\Users\' lower(getenv('username')) '\AppData\Local\Bonsai\'];
    if ~exist(BonsaiPath,'dir') %no luck finding it
        clearvars BonsaiPath
    end
end

for fileNum=1:numel(videoFiles)
    videoFileName=videoFiles(fileNum).name;
    frameSplitIndexFileName = [videoFileName(1:end-4) '_VideoFrameSplitIndex.csv'];
    videoDirectory=[sessionDir filesep];

    if exist('BonsaiPath','var')
        BonsaiWFPath=fullfile(fileparts(mfilename('fullpath')),'VideoOp');
        callFlags= [' -p:Path.CSVFileName=' frameSplitIndexFileName...
                    ' -p:Path.Directory=' videoDirectory...
                    ' -p:Path.VideoFileName=' videoFileName...
                    ' --start --noeditor'];
        switch splitUp
            case 'No'
                BonsaiWFPath=fullfile(BonsaiWFPath, 'SplitVideoByFrameIndex.bonsai');
                sysCall=[BonsaiPath 'Bonsai ' BonsaiWFPath callFlags];
                disp(sysCall); [~,~]= system(sysCall);
            case 'Yes'
                BonsaiWFPath=fullfile(BonsaiWFPath, 'SplitVideoByFrameIndex_SplitLeft.bonsai');
                sysCall=[BonsaiPath 'Bonsai ' BonsaiWFPath callFlags];
                disp(sysCall); [~,~]= system(sysCall);
                BonsaiWFPath=fullfile(BonsaiWFPath, 'SplitVideoByFrameIndex_SplitRight.bonsai');
                sysCall=[BonsaiPath 'Bonsai ' BonsaiWFPath callFlags];
                disp(sysCall); [~,~]= system(sysCall);
        end
    else
        try
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
        catch
            %% use ffmpeg + [optional] Split video in two vertically
            splitIndex=load(frameSplitIndexFileName);
            splitIndex=splitIndex+1; % 1 index
            outputDir = fullfile(videoDirectory, 'WhiskerTracking');

            for chunkNum=1:size(splitIndex,1)
                sysCall=['ffmpeg -y -r ' num2str(frameRate) ' -i ' videoFileName ' -ss ' ...
                    num2str(floor(frameTimes(splitIndex(chunkNum,1))*FRratio)) ' -to '...
                    num2str(floor(frameTimes(splitIndex(chunkNum,2)+1)*FRratio)) ...
                    ' -c:v copy -c:a copy -r ' num2str(frameRate) ' '...
                    outputDir filesep videoFileName(1:end-4) '_Trial' ...
                    num2str(chunkNum-1) '.mp4' ' -async 1 ' ...
                    ' -hide_banner -loglevel panic'];
                disp(sysCall); system(sysCall);


                % check frame number
                vf=[outputDir filesep videoFileName(1:end-4) '_Trial' num2str(chunkNum-1) '.mp4'];
                videoData = py.cv2.VideoCapture(vf);
                chunkFrameNum=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT);

                switch splitUp
                    case 'No'
                    case 'Yes'
                        outF=[outputDir filesep videoFileName(1:end-4) '_Trial' num2str(chunkNum-1) '.mp4'];
                        sysCall=['ffmpeg -y -i ' outF ...
                            ' -vf crop=' num2str(midWidth) ':' num2str(size(vidFrame,1)) ':0:0 ' ...
                            '-c:a copy '...
                            outputDir filesep videoFileName(1:end-4) '_LeftW_Trial' ...
                            num2str(chunkNum-1) '.mp4'];
                        disp(sysCall); system(sysCall);

                        sysCall=['ffmpeg -y -i ' outF ...
                            ' -vf crop=' num2str(midWidth) ':' num2str(size(vidFrame,1))...
                            ':' num2str(midWidth) ':0 ' ...
                            '-c:a copy '...
                            outputDir filesep videoFileName(1:end-4) '_RightW_Trial' ...
                            num2str(chunkNum-1) '.mp4'];
                        disp(sysCall); system(sysCall);

                        % check frame number
                        vf=[outputDir filesep videoFileName(1:end-4) '_Right_Trial' num2str(chunkNum-1) '.mp4'];
                        videoData = py.cv2.VideoCapture(outF);
                        splitChunkFrameNum=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT)
                        if chunkFrameNum~=splitChunkFrameNum
                            disp('inconsistant frame number after split')
                        end
                end

            end
        end
    end
    %             % check frame number
    %         vf=[outputDir filesep 'vIRt50_1021_4736_20201021-194603_HSCam_Trial0.avi'];
    %         videoData = py.cv2.VideoCapture(vf);
    %         chunkFrameNum=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT);
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
end

%% Nested function 
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