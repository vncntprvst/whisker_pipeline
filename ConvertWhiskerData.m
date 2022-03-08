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
    whiskers = struct('angle_raw',[],'angle',[],'timestamp',[],...
        'folX',[],'folY',[],'tipX',[],'tipY',[],'faceX',[],'faceY',[],...
    'curvature',[],'phase',[],'freq',[],'amplitude',[],...
    'setPoint',[],'angle_BP',[],'velocity',[],'WP_Data',[]);
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
            
%             whiskers(whiskNum).angle=whiskers(whiskNum).WP_Data.angle;
%             whiskers(whiskNum).folX=whiskers(whiskNum).WP_Data.follicle_x;
%             whiskers(whiskNum).folY=whiskers(whiskNum).WP_Data.follicle_y;
            
            %% resample (original sampling rate is 1000/mode(diff(TTLSignals)) )            
%             whiskers(whiskNum).WP_Data.timestamp=datetime(syncTTLs(frameIdx),'ConvertFrom','epochtime','Epoch','2020-08-02');
%             whiskers(whiskNum).data=table2timetable(whiskers(whiskNum).WP_Data,'RowTimes','timestamp');
            dataFields = fieldnames(whiskers(whiskNum).WP_Data); 
            whiskers(whiskNum).WP_Data=timeseries(table2array(whiskers(whiskNum).WP_Data),syncTTLs(frameIdx));
            samplingRate=1000;
            whiskers(whiskNum).WP_Data=resample(whiskers(whiskNum).WP_Data,whiskers(whiskNum).WP_Data....
                .Time(1):1/samplingRate:whiskers(whiskNum).WP_Data.Time(end));
            
            % get fields of interest
            whiskers(whiskNum).angle=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'angle'), dataFields))';
            whiskers(whiskNum).folX=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'follicle_x'), dataFields))';
            whiskers(whiskNum).folY=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'follicle_y'), dataFields))';
            whiskers(whiskNum).tipX=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'tip_x'), dataFields))';
            whiskers(whiskNum).tipY=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'tip_y'), dataFields))';
            whiskers(whiskNum).faceX=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'face_x'), dataFields))';
            whiskers(whiskNum).faceY=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'face_y'), dataFields))';
            whiskers(whiskNum).curvature=whiskers(whiskNum).WP_Data.Data(:,...
                cellfun(@(fldName) strcmp(fldName,'curvature'), dataFields))';
           
            
            %% keep timestamp
            whiskers(whiskNum).timestamp=whiskers(whiskNum).WP_Data.Time';
            %% compare with video (sanity check)
            %         frameTimes=syncTTLs-syncTTLs(1);boutIndex=350000:352000;
            %         wBoutFrames=WhiskingBoutVideo([],[],boutIndex,frameTimes);
            %         vidDims=size(wBoutFrames(1).cdata);
            %         figure('position',[1500 450  vidDims(2) vidDims(1)],'color','k');
            %         movie(wBoutFrames,1,500);
            %
            %         figure('position',[1500 450  vidDims(2) vidDims(1)],'color','k');
            %         frameTimeIdx=frameTimes>=boutIndex(1) & frameTimes<=boutIndex(end);
            %         FrameByFrame_Overlay(wBoutFrames,[w(whiskNum).folX(frameTimeIdx),w(whiskNum).folY(frameTimeIdx),w(whiskNum).angle(frameTimeIdx)]);
            
            %% remove outliers
            whiskers(whiskNum).angle_raw=WhiskerAngleSmoothFill(whiskers(whiskNum).angle);
            
            %% compute other measurements
            % find phase and frequency
            [whiskers(whiskNum).phase,whiskers(whiskNum).freq]=WhiskingFun.ComputePhase(whiskers(whiskNum).angle_raw,samplingRate); %WhiskingFun.BandPassBehavData(w(whiskNum).angle,1000,[4 20])
            % find amplitude
            whiskers(whiskNum).amplitude=WhiskingFun.GetAmplitude(whiskers(whiskNum).angle_raw,whiskers(whiskNum).phase);
            % find set-point
            whiskers(whiskNum).setPoint=WhiskingFun.LowPassBehavData(whiskers(whiskNum).angle_raw,1000,4); %WhiskingFun.GetSetPoint(w(whiskNum).angle_raw,w(whiskNum).Phase);
            % filter angle values
            whiskers(whiskNum).angle_BP=WhiskingFun.BandPassBehavData(whiskers(whiskNum).angle_raw,1000,[4 30]); %smoothes out high frequencies and removes set point
            whiskers(whiskNum).angle = WhiskingFun.LowPassBehavData(whiskers(whiskNum).angle_raw,1000,40); %just smoothing out high frequencies
            % derive velocity
            whiskers(whiskNum).velocity=diff(whiskers(whiskNum).angle); whiskers(whiskNum).velocity=[whiskers(whiskNum).velocity(1) whiskers(whiskNum).velocity];
            
            %% if trace is too short, pad with nans
            if numel(whiskers(whiskNum).angle) < numel(syncTTLs)*mode(diff(syncTTLs))
                wFields=fieldnames(whiskers);
                for fieldNum=1:numel(wFields)
                    try whiskers(whiskNum).(wFields{fieldNum})(end+1:numel(syncTTLs)*mode(diff(syncTTLs)))=nan; catch; end
                end
            end
        end
        
        %% export data
        exportFileName=regexp(videoSyncFiles(compIndex).name,'\S+(?=_vSyncTTLs)','match','once');
        fullExportFileName=fullfile(videoSyncFiles(compIndex).folder,[exportFileName '_wMeasurements.mat']);
        save(fullExportFileName,'whiskers','keepWhiskerIDs','bestWhisker','wtData',...
            'syncTTLs','samplingRate','fileName');
%         RemoteSync([exportFileName '_wMeasurements.mat'],replace(videoSyncFiles(compIndex).folder,'SpikeSorting','Analysis'),...
%             videoSyncFiles(compIndex).folder,[],'Sync_ToServer_SpikeSorting')% work on this 
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

