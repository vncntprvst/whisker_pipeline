function ConvertWhiskerData(whiskerData)
% Export whole-recording whisker tracking data
% Run in directory where WhiskerTracking folder is located, typically <SessionFolder>
workDir=cd;

%% List whisker data files
if nargin == 0
    whiskerDataFiles = cellfun(@(fileFormat) dir([workDir filesep '*' filesep fileFormat]),...
        {'*_WhiskerData*'},'UniformOutput', false);
    whiskerDataFiles=vertcat(whiskerDataFiles{~cellfun('isempty',whiskerDataFiles)});
    if isempty(whiskerDataFiles) % Other format types
        whiskerDataFiles=LoadWhiskerData;
    else
        % do not include files in Analysis folder:
        whiskerDataFiles=whiskerDataFiles(~cellfun(@(flnm) contains(flnm,{'Analysis'}),...
            {whiskerDataFiles.folder}));
    end
    numFiles=numel(whiskerDataFiles);
else
    numFiles=numel(whiskerData);
end

%% List sync data files (from ephys export - see BatchExport)
videoSyncFiles = cellfun(@(fileFormat) dir([workDir filesep '*' filesep '*' filesep fileFormat]),...
    {'*vSync*'},'UniformOutput', false);
videoSyncFiles=vertcat(videoSyncFiles{~cellfun('isempty',videoSyncFiles)});
% do not include files in Analysis folder:
videoSyncFiles=videoSyncFiles(~cellfun(@(flnm) contains(flnm,{'Analysis';'vSyncFix'}),...
    {videoSyncFiles.folder}));

%% Convert data
for fileNum=1:numFiles
    clear whiskers wtData whiskingPhase whiskingAngle whiskingVelocity
    whiskers = struct('WP_Data',[],'Angle',[],'folX',[],'folY',[],...
    'Timestamp',[],'Angle_raw',[],'Phase',[],'Freq',[],'Amplitude',[],...
    'SetPoint',[],'Angle_BP',[],'Velocity',[]);
    if nargin == 0
        wtData=load(fullfile(whiskerDataFiles(fileNum).folder,whiskerDataFiles(fileNum).name));
    else
        wtData=whiskerData;
        whiskerDataFiles(fileNum).name=cell2mat(fieldnames(whiskerData));
        whiskerDataFiles(fileNum).folder=cd;
    end
    fileName=fieldnames(wtData);fileName=fileName{1};
    wtData=wtData.(fileName);
    
    if ~isempty(wtData.wid)
        %% get time info from sync TTL
        % find corresponding filename
        for strCompLength=numel(fileName):-1:1
            compIndex=cellfun(@(fName) strncmpi(fileName,fName,strCompLength),...
                {videoSyncFiles.name});
            if sum(compIndex)==1 %found it
                break
            elseif sum(compIndex)==2
                %same basename, but one has a suffix. Keep the shorter one.
                disp('Ambiguity in finding videoSyncFiles:')
                disp(videoSyncFiles(find(compIndex,1)).name)
                disp(videoSyncFiles(find(compIndex,1,'last')).name)
                suffixLength=cellfun(@(fileName) length(fileName(strCompLength:end)),...
                    {videoSyncFiles(compIndex).name});
                compIndex=find(compIndex);
                compIndex=compIndex(suffixLength==min(suffixLength));
                disp(['Using ' videoSyncFiles(compIndex).name])
                break
            end
        end
        
        % load video sync data
        syncDataFile = fopen(fullfile(videoSyncFiles(compIndex).folder,videoSyncFiles(compIndex).name));
        syncTTLs = fread(syncDataFile,'single');
        fclose(syncDataFile);
        
        % convert to table if needed
        if contains(class(wtData),'struct')
            wtData=struct2table(wtData);
        end
        
        %ID whiskers to isolate data for one whisker
        [keepWhiskerIDs,bestWhisker]=FindBestWhisker(wtData,'left');
        
        for whiskNum=1:numel(keepWhiskerIDs)
            whiskers(whiskNum).WP_Data=wtData(wtData.wid==keepWhiskerIDs(whiskNum),:);
            frameIdx=whiskers(whiskNum).WP_Data.fid+1; %frames are zero-indexed
            
            whiskers(whiskNum).Angle=whiskers(whiskNum).WP_Data.angle;
            whiskers(whiskNum).folX=whiskers(whiskNum).WP_Data.follicle_x;
            whiskers(whiskNum).folY=whiskers(whiskNum).WP_Data.follicle_y;
            
            %% resample (original sampling rate is 1000/mode(diff(TTLSignals)) )
            whiskers(whiskNum).Angle=timeseries(whiskers(whiskNum).Angle,syncTTLs(frameIdx)); %Issue with slow TTL drift (1ms every s) -> TTL issued from camera may not be so reliable? OR just the trigger itself
            samplingRate=1000;
            whiskers(whiskNum).Angle=resample(whiskers(whiskNum).Angle,whiskers(whiskNum).Angle....
                .Time(1):1/samplingRate:whiskers(whiskNum).Angle.Time(end));
            
            %% keep timestamp
            whiskers(whiskNum).Timestamp=whiskers(whiskNum).Angle.Time';
            %% compare with video (sanity check)
            %         frameTimes=syncTTLs-syncTTLs(1);boutIndex=350000:352000;
            %         wBoutFrames=WhiskingBoutVideo([],[],boutIndex,frameTimes);
            %         vidDims=size(wBoutFrames(1).cdata);
            %         figure('position',[1500 450  vidDims(2) vidDims(1)],'color','k');
            %         movie(wBoutFrames,1,500);
            %
            %         figure('position',[1500 450  vidDims(2) vidDims(1)],'color','k');
            %         frameTimeIdx=frameTimes>=boutIndex(1) & frameTimes<=boutIndex(end);
            %         FrameByFrame_Overlay(wBoutFrames,[w(whiskNum).folX(frameTimeIdx),w(whiskNum).folY(frameTimeIdx),w(whiskNum).Angle(frameTimeIdx)]);
            
            %% remove outliers
            whiskers(whiskNum).Angle_raw=WhiskerAngleSmoothFill(whiskers(whiskNum).Angle.Data);
            
            %% compute other measurements
            % find phase and frequency
            [whiskers(whiskNum).Phase,whiskers(whiskNum).Freq]=WhiskingFun.ComputePhase(whiskers(whiskNum).Angle_raw,samplingRate); %WhiskingFun.BandPassBehavData(w(whiskNum).Angle,1000,[4 20])
            % find amplitude
            whiskers(whiskNum).Amplitude=WhiskingFun.GetAmplitude(whiskers(whiskNum).Angle_raw,whiskers(whiskNum).Phase);
            % find set-point
            whiskers(whiskNum).SetPoint=WhiskingFun.LowPassBehavData(whiskers(whiskNum).Angle_raw,1000,4); %WhiskingFun.GetSetPoint(w(whiskNum).Angle_raw,w(whiskNum).Phase);
            % filter angle values
            whiskers(whiskNum).Angle_BP=WhiskingFun.BandPassBehavData(whiskers(whiskNum).Angle_raw,1000,[4 30]); %smoothes out high frequencies and removes set point
            whiskers(whiskNum).Angle = WhiskingFun.LowPassBehavData(whiskers(whiskNum).Angle_raw,1000,40); %just smoothing out high frequencies
            % derive velocity
            whiskers(whiskNum).Velocity=diff(whiskers(whiskNum).Angle); whiskers(whiskNum).Velocity=[whiskers(whiskNum).Velocity(1) whiskers(whiskNum).Velocity];
            
            %% if trace is too short, pad with nans
            if numel(whiskers(whiskNum).Angle) < numel(syncTTLs)*mode(diff(syncTTLs))
                wFields=fieldnames(whiskers);
                for fieldNum=1:numel(wFields)
                    try whiskers(whiskNum).(wFields{fieldNum})(end+1:numel(syncTTLs)*mode(diff(syncTTLs)))=nan; catch; end
                end
            end
        end
        
        %% export data
        exportFileName=regexp(videoSyncFiles(compIndex).name,'\S+(?=_vSyncTTLs)','match','once');
        save(fullfile(videoSyncFiles(compIndex).folder,[exportFileName...
            '_wMeasurements.mat']),'whiskers','bestWhisker','wtData',...
            'syncTTLs','samplingRate','fileName');
        % also save the original files' location
        fileID = fopen(fullfile(videoSyncFiles(compIndex).folder,...
            [exportFileName '_WhiskerSyncFilesLoc.txt']),'w');
        fprintf(fileID,'whiskerDataFile = %s\r',fullfile(whiskerDataFiles(fileNum).folder,...
            whiskerDataFiles(fileNum).name));
        fprintf(fileID,'videoSyncFile = %s\r',fullfile(videoSyncFiles(compIndex).folder,...
            videoSyncFiles(compIndex).name));
        fclose(fileID);
    else
        continue
    end
end

