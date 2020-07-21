
sessionDir =cd; 
dirListing=dir(sessionDir);

%% List video files
videoFiles = cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),...
    {'*.mp4','*.avi'},'UniformOutput', false);
videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
cd([cd filesep 'WhiskerTracking'])
wsdirListing=dir(cd);
%% List whisker data files
allwhiskerMeasurementFiles = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
    {'*.measurements'},'UniformOutput', false);
allwhiskerMeasurementFiles=vertcat(allwhiskerMeasurementFiles{~cellfun('isempty',allwhiskerMeasurementFiles)});
% for now, discard curated
allwhiskerMeasurementFiles=allwhiskerMeasurementFiles(~cellfun(@(fileName)...
    contains(fileName,'curated'), {allwhiskerMeasurementFiles.name}));

%% Get whisker data
for fileNum=1:numel(videoFiles)
    videoFileName=videoFiles(fileNum).name;
    % list whisker data files
    whiskerFileIdx=cellfun(@(fName) strfind(fName,videoFileName(1:end-4)),...
        {allwhiskerMeasurementFiles.name},'UniformOutput',false);
    whiskerFileIdx=~cellfun(@isempty,whiskerFileIdx);
    whiskerMeasurmentFiles=allwhiskerMeasurementFiles(whiskerFileIdx,:);
    partNum=cellfun(@(x) str2double(regexp(x,'\d+(?=.measurements)','match')),... %(?<=_\w+)
        {whiskerMeasurmentFiles.name});
    [~,sortFileIdx]=sort(partNum);
    whiskerMeasurmentFiles=whiskerMeasurmentFiles(sortFileIdx,:);
    recordingName=regexprep(videoFileName(1:end-4),'\W','');
    if length(recordingName)>=52 %will be too long once _WhiskerData is added
        recordingName = recordingName(1:51);
    end
    allWhiskerData.(recordingName)=struct(...
        'partID',[],'fid',[],'wid',[],'angle',[],'follicle_x',[],'follicle_y',[]);
    
    for measurmentFile=1:numel(whiskerMeasurmentFiles)
        whiskerData = Whisker.LoadMeasurements(whiskerMeasurmentFiles(measurmentFile).name);
        dataFields=fieldnames(whiskerData);
        % if whiskerData(1).face_x > whiskerData(1).face_y
        %     [whiskerData.follicle]=deal(whiskerData.follicle_x);
        % else
        %     [whiskerData.follicle]=deal(whiskerData.follicle_y);
        % end
        whiskerData=rmfield(whiskerData,dataFields([3,4,5,6,7,9,12,13])); %11,12,
        dataFields=fieldnames(whiskerData);
        
        currentDim=numel(allWhiskerData.(recordingName).partID);
        if currentDim==1, currentDim=0; end
        entryRange=currentDim+1:currentDim+numel(whiskerData);
        allWhiskerData.(recordingName).partID(entryRange,1)=measurmentFile;
        for datafieldNum=1:5
            allWhiskerData.(recordingName).(dataFields{datafieldNum})(entryRange,1)=[whiskerData.(dataFields{datafieldNum})];
        end
        if entryRange(1)>1
            allWhiskerData.(recordingName).fid(entryRange,1)=...
                allWhiskerData.(recordingName).fid(entryRange,1)+...
                allWhiskerData.(recordingName).fid(entryRange(1)-1)+1;
        end
    end
end

%% Save data
save('allWhiskerData','allWhiskerData')
fileNames=fieldnames(allWhiskerData);
for fileNum=1:numel(fileNames)
    eval([fileNames{fileNum} '_WhiskerData=allWhiskerData.(fileNames{fileNum})']);
    save([fileNames{fileNum} '_WhiskerData.mat'],[fileNames{fileNum} '_WhiskerData']);
end

%% Plot
% dt=0.002;
% time=double([allWhiskerData.(recordingName).fid]).*dt;
% angle=[allWhiskerData.(recordingName).angle];
% colors=['r','k','g','b','c','m'];
% figure;clf;
% hold on;
% for whisker_id=1:2%max([allWhiskerData.(recordingName)(:).wid])
%     mask = [allWhiskerData.(recordingName).wid]==whisker_id;
%     plot(time(mask),angle(mask));%colors(whisker_id+1)
% end


