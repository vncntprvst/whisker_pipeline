function FixSync(whiskerData)
% Fixes TTLs to sync video-based whisker tracking time values. 
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
    fileNum=numel(whiskerDataFiles);
else
    fileNum=numel(whiskerData);
end

%% List sync data files (from ephys export - see BatchExport)
videoSyncFiles = cellfun(@(fileFormat) dir([workDir filesep '*' filesep '*' filesep fileFormat]),...
    {'*vSync*'},'UniformOutput', false);
videoSyncFiles=vertcat(videoSyncFiles{~cellfun('isempty',videoSyncFiles)});
if isempty(videoSyncFiles); disp('No sync file found'); return; end
% do not include files in Analysis folder:
videoSyncFiles=videoSyncFiles(~cellfun(@(flnm) contains(flnm,{'Analysis';'vSyncFix'}),...
    {videoSyncFiles.folder}));

%% List sync fix files, if any
syncFixFiles = cellfun(@(fileFormat) dir([workDir filesep fileFormat]),...
    {'*vSyncFix*'},'UniformOutput', false);
syncFixFiles=vertcat(syncFixFiles{~cellfun('isempty',syncFixFiles)});

%% Convert data
for fileNum=1:fileNum
    clear w whiskingPhase whiskingAngle whiskingVelocity
    if nargin == 0
        w.WP_Data=load(fullfile(whiskerDataFiles(fileNum).folder,whiskerDataFiles(fileNum).name));
    else
        w.WP_Data=whiskerData;
        whiskerDataFiles(fileNum).name=cell2mat(fieldnames(whiskerData));
        whiskerDataFiles(fileNum).folder=cd;
    end
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
        
        if ~isempty(syncFixFiles)
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
                syncTTLs=single(syncTTLs);
                % overwrite video sync data
                fclose all;
                delete(fullfile(videoSyncFiles(compIndex).folder,videoSyncFiles(compIndex).name))
                syncDataFile = fopen([fullfile(videoSyncFiles(compIndex).folder,...
                    videoSyncFiles(compIndex).name(1:end-4)) '_Fixed.dat'],'w');
                fwrite(syncDataFile,syncTTLs,'single');
                fclose(syncDataFile);
            end
        end
        
    else
        continue
    end
end

