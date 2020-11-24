function allWhiskerData=BindMeasurements(videoFiles,allwhiskerMeasurementFiles,saveData)
if isempty(videoFiles)
    sessionDir =cd;
    dirListing=dir(sessionDir);
    try
        %% List video files
        videoFiles = cellfun(@(fileFormat) dir([sessionDir filesep fileFormat]),...
            {'*.mp4','*.avi'},'UniformOutput', false);
        videoFiles=vertcat(videoFiles{~cellfun('isempty',videoFiles)});
        cd([cd filesep 'WhiskerTracking'])
        wsdirListing=dir(cd);
    catch
        return
    end
end
if isempty(allwhiskerMeasurementFiles)
    try
        %% List whisker data files
        allwhiskerMeasurementFiles = cellfun(@(fileFormat) dir([cd filesep fileFormat]),...
            {'*.measurements'},'UniformOutput', false);
        allwhiskerMeasurementFiles=vertcat(allwhiskerMeasurementFiles{~cellfun('isempty',allwhiskerMeasurementFiles)});
        % for now, discard curated
        allwhiskerMeasurementFiles=allwhiskerMeasurementFiles(~cellfun(@(fileName)...
            contains(fileName,'curated'), {allwhiskerMeasurementFiles.name}));
    catch
        cd ..
        return
    end
end

%load whisker pad info
if ~exist(fullfile(cd,'whiskerpad.json'),'file')
    vid = VideoReader(fullfile(videoFiles(1).folder,videoFiles(1).name));
    whiskingParams=WhiskingFun.DrawWhiskerPadROI(vid);
    WhiskingFun.SaveWhiskingParams(whiskingParams,cd)
end

whiskerpad = jsondecode(fileread(fullfile(cd,'whiskerpad.json')));
% if numel(whiskerpad)>1 %video was split up in half
%     vid = VideoReader(fullfile(videoFiles(1).folder,videoFiles(1).name));
%     midWidth=round(vid.Width/2);
% end

%% Get whisker data
for fileNum=1:numel(videoFiles)
    videoFileName=videoFiles(fileNum).name;
    % list whisker data files
    whiskerFileIdx=cellfun(@(fName) strfind(fName,videoFileName(1:end-4)),...
        {allwhiskerMeasurementFiles.name},'UniformOutput',false);
    whiskerFileIdx=~cellfun(@isempty,whiskerFileIdx);
    wmFiles=allwhiskerMeasurementFiles(whiskerFileIdx,:);
    partNum=cellfun(@(x) str2double(regexp(x,'\d+(?=.measurements)','match')),... %(?<=_\w+)
        {wmFiles.name});
    [partNum,sortFileIdx]=sort(partNum);
    wmFiles=wmFiles(sortFileIdx,:);
    recordingName=regexprep(videoFileName(1:end-4),'\W','');
    vid = VideoReader(strrep(wmFiles(1).name,'.measurements','.mp4'));
    vidNumFrames=vid.Duration*vid.FrameRate;
    frameWidth=vid.Width;
    if length(recordingName)>=52 %will be too long once _WhiskerData is added
        recordingName = recordingName(1:51);
    end
    allWhiskerData.(recordingName)=struct(...
        'partID',[],'fid',[],'wid',[],...
        'angle',[],'length',[],'curvature',[],...
        'follicle_x',[],'follicle_y',[],'tip_x',[],'tip_y',[],...
        'face_x',[],'face_y',[],...
        'label',[],'score',[]);
    
    % deal with cases with measurements on both sides of the head
    sideIndex=zeros(numel(wmFiles),1);
    for mFileNum=1:numel(wmFiles)
        if mFileNum>1 && partNum(mFileNum)==partNum(mFileNum-1)
            sideIndex(mFileNum)=1;
        end
    end
    %reorder files 
    reIndex=[find(sideIndex==0);find(sideIndex==1)];
    wmFiles=wmFiles(reIndex,:);
    widRaiseIdx=find(ismember(reIndex,find(sideIndex==1)));
    
    % Concatenate whisker data from all chunks
    numFrames=nan(numel(wmFiles),1);
    for mFileNum=1:numel(wmFiles)
        mfName=wmFiles(mFileNum).name;
        whiskerData = Whisker.LoadMeasurements(mfName);
%         whiskerVals=Whisker.LoadWhiskers(strrep(mfName,'.measurements','.whiskers'));

%         overlap_whiskers_on_video(strrep(mfName,'.measurements',''),1)
        
        % remove whiskers outside whiskerpad area
        [whiskerData,blacklist]=WhiskingFun.RestrictToWhiskerPad(whiskerData,...
            whiskerpad(sideIndex(reIndex(mFileNum))+1).Coordinates,...
            whiskerpad(sideIndex(reIndex(mFileNum))+1).ImageDimensions);
        % -> apply to .whisker data 
%         whiskerVals=whiskerVals(~blacklist,:);
        
        % remove non-whisker objects 
        labelIdx=[whiskerData.label]>=0;
        whiskerData = whiskerData(labelIdx,:); 
        % -> apply to .whisker data 
%         whiskerVals=whiskerVals(labelIdx,:);

        if isempty(whiskerData); continue; end
        
        % Fix IDs - 
%         FixWhiskerID(whiskerData);
        
        if any(ismember(widRaiseIdx,mFileNum))
            if mFileNum==widRaiseIdx(1)
                % find how much to increase the whisker id number
                widRaise = max([allWhiskerData.(recordingName).wid])+1;
            end
            widVals = num2cell([whiskerData.wid]);
            widVals = cellfun(@(x) x+widRaise,widVals,'UniformOutput',false);
            [whiskerData.wid] = widVals{:};
        end
        
        currentDim=numel(allWhiskerData.(recordingName).partID);
        if currentDim==1, currentDim=0; end
        entryRange=currentDim+1:currentDim+numel(whiskerData);
        allWhiskerData.(recordingName).partID(entryRange,1)=partNum(reIndex(mFileNum));
              
        dataFields=fieldnames(whiskerData);
        for datafieldNum=1:numel(dataFields)
            if any(ismember(widRaiseIdx,mFileNum)) && any(strfind(dataFields{datafieldNum},'_x'))
                % if right side whiskers, add left side image x dim to right side's x values
                allWhiskerData.(recordingName).(dataFields{datafieldNum})(entryRange,1)=...
                    [whiskerData.(dataFields{datafieldNum})]+frameWidth;
            else
                allWhiskerData.(recordingName).(dataFields{datafieldNum})(entryRange,1)=...
                    [whiskerData.(dataFields{datafieldNum})];
            end
        end
        numFrames(mFileNum)=numel(unique([whiskerData.fid]));
    end
    
    % All chunks are assumed to have the same number of frames (except the last one, which is fine)
    numFrames=mode(numFrames);
    if numFrames~=vidNumFrames
        disp({['inconsistent number of frames vs fids for ' ...
            wmFiles(mFileNum).name]; ...
            ['Number of frames: ' num2str(vidNumFrames)];
            ['Number of fids: ' num2str(numFrames)]})
%         return
    end
    
    % adjust fids
    for mFileNum=1:numel(unique(partNum))
        numPrecedFrame=numFrames*partNum(reIndex(mFileNum));
        entryRange=ismember([allWhiskerData.(recordingName).partID],mFileNum-1);
        allWhiskerData.(recordingName).fid(entryRange,1)=...
            allWhiskerData.(recordingName).fid(entryRange,1)+numPrecedFrame;
    end

    % reorder fids in case there were multiple measurements files for each video chunk
    [~, sortFrames]=sort([allWhiskerData.(recordingName).fid]);
    dataFields=fieldnames(allWhiskerData.(recordingName));
    for datafieldNum=1:numel(dataFields)
        allWhiskerData.(recordingName).(dataFields{datafieldNum})=...
            allWhiskerData.(recordingName).(dataFields{datafieldNum})(sortFrames);
    end
    
end

%% Save data
if saveData
    save('allWhiskerData','allWhiskerData')
    fileNames=fieldnames(allWhiskerData);
    for fileNum=1:numel(fileNames)
        eval([fileNames{fileNum} '_WhiskerData=allWhiskerData.(fileNames{fileNum})']);
        save([fileNames{fileNum} '_WhiskerData.mat'],[fileNames{fileNum} '_WhiskerData']);
    end
end
if isempty(videoFiles)
    cd(sessionDir)
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


