function SaveWhiskerData(sessionDir)

if nargin == 0; sessionDir = cd; end

[dirPath,dirFolder]=fileparts(sessionDir);
if strcmp(dirFolder,'WhiskerTracking'); sessionDir=dirPath; end

try
    %% List video files
    videoFiles = cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),...
        {'*.mp4','*.avi'},'UniformOutput', false);
    videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
    cd(fullfile(sessionDir,'WhiskerTracking'))
    %% List whisker data files
    whiskerMeasurementFiles = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
        {'*.measurements'},'UniformOutput', false);
    whiskerMeasurementFiles=vertcat(whiskerMeasurementFiles{~cellfun('isempty',whiskerMeasurementFiles)});
    % for now, discard curated
    whiskerMeasurementFiles=whiskerMeasurementFiles(~cellfun(@(fileName)...
        contains(fileName,'curated'), {whiskerMeasurementFiles.name}));
catch
    disp(['No video or measurement files in ' sessionDir])
    return
end

for fileNum=1:numel(videoFiles)
    % get measurements
    try
        cd(fullfile(sessionDir,'WhiskerTracking'))
        whiskerData=BindMeasurements(videoFiles(fileNum),whiskerMeasurementFiles,false);
        % Fix sync TTLs if necessary 
        cd(sessionDir)
        FixSync(whiskerData); %should skip this if unneeded
        % convert angles to advanced values (phase, etc ...) and save them 
        ConvertWhiskerData(whiskerData);
    catch ME
        disp(['failed converting whisker data for ' videoFiles(fileNum).name])
        disp(ME.identifier)
%       rethrow(ME)
    end
end
