function ConvertWhiskerData
% Export whole-recording whisker tracking data
% Run in directory where WhiskerTracking folder is located, typically <SessionFolder>
workDir=cd;

%% List whisker data files
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

%% List sync data files (from ephys export - see BatchExport)
videoSyncFiles = cellfun(@(fileFormat) dir([workDir filesep '*' filesep '*' filesep fileFormat]),...
    {'*vSync*'},'UniformOutput', false);
videoSyncFiles=vertcat(videoSyncFiles{~cellfun('isempty',videoSyncFiles)});
% do not include files in Analysis folder:
videoSyncFiles=videoSyncFiles(~cellfun(@(flnm) contains(flnm,{'Analysis';'vSyncFix'}),...
    {videoSyncFiles.folder}));

%% List sync fix files, if any
syncFixFiles = cellfun(@(fileFormat) dir([workDir filesep fileFormat]),...
    {'*vSyncFix*'},'UniformOutput', false);
syncFixFiles=vertcat(syncFixFiles{~cellfun('isempty',syncFixFiles)});

%% Convert data
for fileNum=1:numel(whiskerDataFiles)
    clear w whiskingPhase whiskingAngle whiskingVelocity
    
    w.WP_Data=load(fullfile(whiskerDataFiles(fileNum).folder,whiskerDataFiles(fileNum).name));
    w.FileName=fieldnames(w.WP_Data);w.FileName=w.FileName{1};
    w.WP_Data=w.WP_Data.(w.FileName);
    
    if ~isempty(w.WP_Data.wid)
        %% get time info from sync TTL
        % find corresponding filename
        for strCompLength=numel(w.FileName):-1:1
            compIndex=cellfun(@(fileName) strncmpi(w.FileName,fileName,strCompLength),...
                {videoSyncFiles.name});
            if sum(compIndex)==1 %found it
                break
            end
        end
        % load video sync data
        syncDataFile = fopen(fullfile(videoSyncFiles(compIndex).folder,videoSyncFiles(compIndex).name));
        syncTTLs = fread(syncDataFile,'double');
        fclose(syncDataFile);
        
        syncFixIdx=cellfun(@(fF) contains(fF,videoSyncFiles(compIndex).name(1:end-14)), {syncFixFiles.name});
        if any(syncFixIdx) & ~contains(videoSyncFiles(compIndex).name,'Fixed')
            load(fullfile(syncFixFiles(syncFixIdx).folder,syncFixFiles(syncFixIdx).name));
            for fixNum=1:numel(vSyncFix)
                switch vSyncFix(fixNum).fixType
                    case 'disregard'
                        syncTTLs(vSyncFix(fixNum).fixIndex)=NaN;
                    case 'add' %need to code that
                    case 'none' %all clear
                end
            end
            syncTTLs=syncTTLs(~isnan(syncTTLs));
        
            % overwrite video sync data
            fclose all;
            delete(fullfile(videoSyncFiles(compIndex).folder,videoSyncFiles(compIndex).name))
            syncDataFile = fopen([fullfile(videoSyncFiles(compIndex).folder,...
                videoSyncFiles(compIndex).name(1:end-4)) '_Fixed.dat'],'w');
            fwrite(syncDataFile,syncTTLs,'double');
            fclose(syncDataFile);
        end

        % get data for one whisker
        
        Need to add fix if frame 0 does not have data
        
        frameIdx=w.WP_Data.fid(w.WP_Data.wid==1);
        if frameIdx(1)==0; frameIdx=frameIdx+1; end
        
        w.Angle=w.WP_Data.angle(w.WP_Data.wid==1);
        w.folX=w.WP_Data.follicle_x(w.WP_Data.wid==1);
        w.folY=w.WP_Data.follicle_y(w.WP_Data.wid==1);

        %% resample (original sampling rate is 1000/mode(diff(TTLSignals)) )
        w.Angle=timeseries(w.Angle,syncTTLs(frameIdx)); %Issue with slow TTL drift (1ms every s) -> TTL issued from camera may not be so reliable? OR just the trigger itself
        w.Angle=resample(w.Angle,w.Angle.Time(1):w.Angle.Time(end));
        samplingRate=1000;
        
        %% compare with video (sanity check)
%         frameTimes=syncTTLs-syncTTLs(1);boutIndex=350000:352000;
%         wBoutFrames=WhiskingBoutVideo([],[],boutIndex,frameTimes);
%         vidDims=size(wBoutFrames(1).cdata);
%         figure('position',[1500 450  vidDims(2) vidDims(1)],'color','k');
%         movie(wBoutFrames,1,500);
% 
%         figure('position',[1500 450  vidDims(2) vidDims(1)],'color','k');
%         frameTimeIdx=frameTimes>=boutIndex(1) & frameTimes<=boutIndex(end);
%         FrameByFrame_Overlay(wBoutFrames,[w.folX(frameTimeIdx),w.folY(frameTimeIdx),w.Angle(frameTimeIdx)]);

        %% remove outliers
        w.Angle_raw=WhiskerAngleSmoothFill(w.Angle.Data);
      
        %% compute other measurements
        % find phase and frequency
        [w.Phase,w.Freq]=WhiskingFun.ComputePhase(w.Angle_raw,samplingRate); %WhiskingFun.BandPassBehavData(w.Angle,1000,[4 20])    
        % find amplitude 
        w.Amplitude=WhiskingFun.GetAmplitude(w.Angle_raw,w.Phase);
        % find set-point
        w.SetPoint=WhiskingFun.LowPassBehavData(w.Angle_raw,1000,4); %WhiskingFun.GetSetPoint(w.Angle_raw,w.Phase);
        % filter angle values        
        w.Angle_BP=WhiskingFun.BandPassBehavData(w.Angle_raw,1000,[4 30]); %smoothes out high frequencies and removes set point 
        w.Angle = WhiskingFun.LowPassBehavData(w.Angle_raw,1000,40); %just smoothing out high frequencies
        % derive velocity
        w.Velocity=diff(w.Angle); w.Velocity=[w.Velocity(1) w.Velocity];
        
        %% if trace is too short, pad with nans
        if numel(w.Angle) < numel(syncTTLs)*mode(diff(syncTTLs))
            wFields=fieldnames(w);
            for fieldNum=1:numel(wFields)
                try w.(wFields{fieldNum})(end+1:numel(syncTTLs)*mode(diff(syncTTLs)))=nan; catch; end
            end
        end
        
        %% export data
        exportFileName=regexp(videoSyncFiles(compIndex).name,'\S+(?=_vSyncTTLs.dat)','match','once');
        save(fullfile(videoSyncFiles(compIndex).folder,[exportFileName...
            '_wMeasurements.mat']),'-struct','w');
        save(fullfile(videoSyncFiles(compIndex).folder,[exportFileName...
            '_wMeasurements.mat']),'syncTTLs','samplingRate','-append');
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

