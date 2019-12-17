workDir=cd;
% List whisker data files
whiskerDataFiles = cellfun(@(fileFormat) dir([workDir filesep '*' filesep fileFormat]),...
    {'*_WhiskerData*'},'UniformOutput', false);
whiskerDataFiles=vertcat(whiskerDataFiles{~cellfun('isempty',whiskerDataFiles)});
% List sync data files
videoSyncFiles = cellfun(@(fileFormat) dir([workDir filesep '*' filesep '*' filesep fileFormat]),...
    {'*vSync*'},'UniformOutput', false);
videoSyncFiles=vertcat(videoSyncFiles{~cellfun('isempty',videoSyncFiles)});

%% Convert data
for fileNum=1:numel(whiskerDataFiles)
    clear whiskingPhase whiskingAngle whiskingVelocity
    
    whiskerData=load(fullfile(whiskerDataFiles(fileNum).folder,whiskerDataFiles(fileNum).name));
    whiskerFileName=fieldnames(whiskerData);whiskerFileName=whiskerFileName{1};
    whiskerData=whiskerData.(whiskerFileName);
    
    if ~isempty(whiskerData.wid)
        %% get time info from sync TTL
        % find corresponding filename
        for strCompLength=numel(whiskerFileName):-1:1
            compIndex=cellfun(@(fileName) strncmpi(whiskerFileName,fileName,strCompLength),...
                {videoSyncFiles.name});
            if sum(compIndex)==1 %found it
                break
            end
        end
        % load video sync data
        dataFile = fopen(fullfile(videoSyncFiles(compIndex).folder,videoSyncFiles(compIndex).name));
        TTLSignals = fread(dataFile,'int32');
        fclose(dataFile);
        
        % get data for one whisker
        frameIdx=whiskerData.fid(whiskerData.wid==1);
        if frameIdx(1)==0; frameIdx=frameIdx+1; end
        
        whiskingAngle=whiskerData.angle(whiskerData.wid==1);
        
        % resample (original sampling rate is 1000/mode(diff(TTLSignals)) )
        whiskingAngle = timeseries(whiskingAngle,TTLSignals(frameIdx));
        whiskingAngle=resample(whiskingAngle,whiskingAngle.Time(1):whiskingAngle.Time(end));
        samplingRate=1000;
        
        % remove outliers
        whiskingAngle=WhiskerAngleSmoothFill(whiskingAngle.Data);
        
        %compute velocity and phase
        % find phase
        onewhiskingPhase=WhiskingAnalysisFunctions.ComputePhase(...
            WhiskingAnalysisFunctions.BandPassBehavData(whiskingAngle,1000,[4 20]))';
        % filter angle values
        oneWhiskingAngle=WhiskingAnalysisFunctions.LowPassBehavData(whiskingAngle,1000,40)';
        % derive velocity
        onewhiskingVelocity=diff(whiskingAngle)'; onewhiskingVelocity=[onewhiskingVelocity(1);onewhiskingVelocity];
        
        % export angle, velocity, phase
        exportFileName=regexp(videoSyncFiles(compIndex).name,'\S+(?=_vSyncTTLs.dat)','match','once');
        save(fullfile(videoSyncFiles(compIndex).folder,[exportFileName '_whiskerangle.mat']),...
            'oneWhiskingAngle','samplingRate');
        save(fullfile(videoSyncFiles(compIndex).folder,[exportFileName '_whiskervelocity.mat']),...
            'onewhiskingVelocity','samplingRate');
        save(fullfile(videoSyncFiles(compIndex).folder,[exportFileName '_whiskerphase.mat']),...
            'onewhiskingPhase','samplingRate');
    else
        continue
    end
end

