function [frameTimes,frameRate] = CreateVideoTimeSplitFile(videoFiles,timestampFiles,sessionDir,writeFile)
currDir = cd;
if ~exist('sessionDir','var'); sessionDir = currDir; end
if ~exist('writeFile','var'); writeFile = true; end
cd(sessionDir);

% pre-allocate
[frameTimes,frameRate]=deal(cell(numel(videoFiles),1));

% Write Frame Split Index File
for fileNum=1:numel(videoFiles)
    clearvars videoData numFrames compIndex videoTimestamps
    videoFileName=videoFiles(fileNum).name;
    videoData = py.cv2.VideoCapture(videoFileName);
    numFrames=videoData.get(py.cv2.CAP_PROP_FRAME_COUNT);
    % find corresponding frame timestamp file, comparing with video file name (they
    % might not be exactly the same, to due timestamp in filename)
    if ~isempty(timestampFiles)
        for strCompLength=numel(videoFileName):-1:1
            compIndex=cellfun(@(fileName) strncmpi(videoFileName(1:end-4),...
                fileName,strCompLength), {timestampFiles.name});
            if sum(compIndex)==1 %found it
                break
            elseif sum(compIndex)==2
                %same basename, but one has a suffix. Keep the shorter one.
                disp('Ambiguity in finding timestampFiles. Assuming one has a suffix')
                suffixLength=cellfun(@(fileName) length(fileName(strCompLength:end)),...
                    {timestampFiles(compIndex).name});
                compIndex=find(compIndex);
                compIndex=compIndex(suffixLength==min(suffixLength));
                break
            end
        end
        videoTimestampFile=fullfile(timestampFiles(compIndex).folder,timestampFiles(compIndex).name);
        % read timestamps
        [~,~,tsFileExt] = fileparts(videoTimestampFile);
        switch tsFileExt
            case '.dat' %sync file output from actual TTLs
                syncFile = fopen(videoTimestampFile, 'r');
                fTimes = fread(syncFile,'single');%'int32' % VideoFrameTimes: was fread(fid,[2,Inf],'double'); Adjust export
                fclose(syncFile);
            case '.csv' %computer side timestamps saved as backup option
                videoTimestamps=readtable(videoTimestampFile);
                if any(ismember({'RelativeCameraFrameTime'}, videoTimestamps.Properties.VariableNames))
                    fTimes=videoTimestamps.RelativeCameraFrameTime/10^9; %in sec
                elseif numel(fieldnames(videoTimestamps))==7
                    %% See ParseCSV_timestamps.bonsai for conversion.
                    %                     continue
                    fTimes=(1:2:numFrames*2)-1;fTimes=fTimes';
                elseif all(ismember({'Hour','Minute','Second'}, videoTimestamps.Properties.VariableNames))
                    fTimes=videoTimestamps.Hour*3600+videoTimestamps.Minute*60+videoTimestamps.Second;
                    fTimes=fTimes-fTimes(1);
                    fTimes=fTimes*1000;
                end
            case '.bin' %Paul's plugin
                TSfileID=fopen(videoTimestampFile,'r');
                videoTimestamps=fread(TSfileID,[3 Inf],'int64'); %see line 121 https://github.com/paulmthompson/BaslerCameraPlugin/blob/master/BaslerCamera/BaslerCameraEditor.cpp
                fclose(TSfileID);
                fTimes=videoTimestamps(1,find(videoTimestamps(3,:)>0,1):end)-...
                    videoTimestamps(1,find(videoTimestamps(3,:)>0,1));
                %                 frameTimes=videoTimestamps(1,:)-videoTimestamps(1,1);
                fTimes=linspace(0,fTimes(end),numFrames);
                fTimes=fTimes'/30; %recorded at 30kHz
        end
        frameDur=unique(round(diff(fTimes)*1000));

        if numel(frameDur)>1
            % go back and double check TTLs too:
            [recFile,recDir] = uigetfile({'*.dat;*.bin;*.continuous;*.kwik;*.kwd;*.kwx;*.nex;*.ns*','All Data Formats';...
                '*.*','All Files' },['Select TTL file for video ' videoFileName],cd);
            [~,~,~,TTLs] =LoadEphysData(recFile,recDir);%vIRt44_1210_5101.ns6 recDir='D:\Vincent\vIRt44\vIRt44_1210';
            %         foo=diff(TTLs{1, 2}.TTLtimes  );
            %         [ipiFreq,uniqueIPIs]=hist(foo,unique(double(foo)))

            %         if BR rec:
            triggerTimes=TTLs{1, 2}(2).start/TTLs{1, 2}(2).samplingRate*1000; %TTLs{1, 2}.TTLtimes
            %         if OE rec:
            %         triggerTimes = TTLs{1, 2}(1,TTLs{1, 2}(2,:)>0)/30;
            if numel(triggerTimes)>12 %if not old setup
                triggerTimes=triggerTimes'-triggerTimes(1);

                %             clockDrift=(mode(frameTimes./floor(frameTimes))-1)/frameDur(1);
                %             round(frameTimes-(clockDrift*floor(frameTimes)));

                %% find gaps
                contPeriods=bwconncomp([true;round(diff(triggerTimes))==mode(diff(triggerTimes))]);
                gapIndex=cellfun(@(contPIdx) [contPIdx(1);contPIdx(end)], contPeriods.PixelIdxList, 'UniformOutput', false);
                gapIndex=reshape([gapIndex{:}],[1 numel(gapIndex)*2]); trigGapIndex=reshape(gapIndex,[2,numel(gapIndex)/2]);

                contPeriods=bwconncomp([true,round(diff(fTimes'))==mode(round(diff(fTimes)))]);
                if contPeriods.NumObjects~=size(trigGapIndex,2)
                    disp(['serious frame number mismatch for' videoFiles(fileNum).name])
                    continue
                end
                gapIndex=cellfun(@(contPIdx) [contPIdx(1);contPIdx(end)], contPeriods.PixelIdxList, 'UniformOutput', false);
                gapIndex=reshape([gapIndex{:}],[1 numel(gapIndex)*2]); frameTimeGapIndex=reshape(gapIndex,[2,numel(gapIndex)/2]);

                %% Probably need to (re)export vSync then . But coordinate with Batch export (ask to overwrite, etc)
                % For now, save index fix
                vSyncFix=struct('fixIndex',[],'fixType',[]);
                for contPeriodNum=1:contPeriods.NumObjects
                    gapDiff=diff(trigGapIndex(:,contPeriodNum)) - diff(frameTimeGapIndex(:,contPeriodNum));
                    if gapDiff>0 % will need to disregard those indices
                        %                     videoTimestamps=[videoTimestamps(frameTimeGapIndex(1,contPeriodNum):videoTimestamps(frameTimeGapIndex(2,contPeriodNum));
                        vSyncFix(contPeriodNum).fixIndex=trigGapIndex(2,contPeriodNum)-gapDiff+1:trigGapIndex(2,contPeriodNum);
                        vSyncFix(contPeriodNum).fixType='disregard';
                    elseif gapDiff<0 % will need to add those indices
                        vSyncFix(contPeriodNum).fixIndex=trigGapIndex(2,contPeriodNum)+1:trigGapIndex(2,contPeriodNum)+gapDiff;
                        vSyncFix(contPeriodNum).fixType='add';
                    else
                        vSyncFix(contPeriodNum).fixIndex=[];
                        vSyncFix(contPeriodNum).fixIndex='none';
                    end
                end
                save([videoFileName(1:end-4) '_vSyncFix.mat'],'vSyncFix');

                %             % diagnostics plots
                %             figure; hold on
                %             plot(diff([triggerTimes';frameTimes']));
                %             %plot(diff([triggerTimes(end-numel(frameTimes)+1:end)';frameTimes']))
                %             %plot(diff([triggerTimes(1:numel(frameTimes))';frameTimes']))
                %             plot(diff(triggerTimes))
                %             plot(diff(frameTimes))
                %
                %             figure; hold on
                %             plot(triggerTimes,triggerTimes,'dk')
                %             plot(frameTimes,frameTimes,'or');
                %
                %             for contPeriodNum=1:contPeriods.NumObjects
                %                 figure; hold on
                %                 plot(triggerTimes(trigGapIndex(1,contPeriodNum):trigGapIndex(2,contPeriodNum))-...
                %                     triggerTimes(trigGapIndex(1,contPeriodNum)),...
                %                     triggerTimes(trigGapIndex(1,contPeriodNum):trigGapIndex(2,contPeriodNum))-...
                %                     triggerTimes(trigGapIndex(1,contPeriodNum)),'dk')
                %                 plot(frameTimes(frameTimeGapIndex(1,contPeriodNum):frameTimeGapIndex(2,contPeriodNum))-...
                %                     frameTimes(frameTimeGapIndex(1,contPeriodNum)),...
                %                     frameTimes(frameTimeGapIndex(1,contPeriodNum):frameTimeGapIndex(2,contPeriodNum))-...
                %                     frameTimes(frameTimeGapIndex(1,contPeriodNum)),'or');
                %             end

            else
                fTimes=fTimes(1:numFrames);
            end
        else
            if numel(fTimes)>numFrames
                fTimes=fTimes(1:numFrames);
            elseif numel(fTimes)==numFrames-1 %extra frame recorded
                fTimes=[fTimes;fTimes(end)+ mode(diff(fTimes))];
            end
        end
    else
        fTimes=table(linspace(1,numFrames*2,numFrames)','VariableNames',{'Var1'});
    end
    % check that video has as many frames as timestamps
    if diff([size(fTimes,1),numFrames])>1
        disp(['discrepancy in frame number for file ' videoFileName])
        continue
    else %do the splitting
        chunkDuration=5; % duration of chunks in seconds
        %Based on Timestamp (unfortunately, Basler cam clocks are not reliable)
        %         videoTimestamps=videoTimestamps.RelativeCameraFrameTime;
        %         chunkIndex=find([0;diff(mod(videoTimestamps/10^9,chunkDuration))]<0); % find the 5 second video segments
        %         %make 2 columns: start and stop indices
        %         chunkIndex=int32([1,chunkIndex(1,1);chunkIndex(1:end-1),chunkIndex(2:end)]);

        % based on absolute time
        if exist('videoTimestamps','var') & isfield(videoTimestamps,'Properties')
            if ismember('RelativeCameraFrameTime', videoTimestamps.Properties.VariableNames)
                frameTimeInterval=unique(round(diff(videoTimestamps.RelativeCameraFrameTime/10^6))); %in ms
            else
                frameTimeInterval=round(mean(diff(videoTimestamps.Var1)));
            end
        else
            frameTimeInterval=frameDur;
        end
        if numel(frameTimeInterval)>1
            if exist('vSyncFix','var'); frameTimeInterval=frameTimeInterval(1); %fine, proceed
            else; disp('Fix frame interval first'); end
        end
        frameTimeInterval=frameTimeInterval/1000;
        if writeFile
            chunkIndex=0:chunkDuration/frameTimeInterval:numFrames;
            chunkIndex=int32([chunkIndex(1:end-1)',chunkIndex(2:end)'-1]);
            % write the file
            frameSplitIndexFileName=[videoFileName(1:end-4) '_VideoFrameSplitIndex.csv'];
            dlmwrite([sessionDir filesep frameSplitIndexFileName],chunkIndex,'delimiter', ',','precision','%i');
        end
    end
    frameTimes{fileNum}=fTimes-fTimes(1);
    frameRate{fileNum}=1/frameTimeInterval;
end

cd(currDir);

% read the csv file:
% chunkIndex=readmatrix([sessionDir filesep frameSplitIndexFileName]);