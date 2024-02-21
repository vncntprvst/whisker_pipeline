function wData=FixWhiskerID(wData,whiskerpad)

% get most typical whisker id
wLabels=double([wData.label]); wIDs=double([wData.wid]);
wLabels=wLabels(wLabels>=0); wIDs=wIDs(wIDs>=0);
[wFreq,uniqueWIDs]=hist(wIDs,unique(wIDs));
ufIds=unique([wData.fid]);
keepWhiskerID=uniqueWIDs(wFreq/numel(ufIds)>0.3);
if isempty(keepWhiskerID)
    disp('Poor tracking. Whisker IDs can''t be fixed')
    return
end
% find which axis to segregate them
switch whiskerpad(1).ProtractionDirection
    case {'downward','upward'}
        fol_axis='follicle_y';
    case {'leftward','rightward'}
        fol_axis='follicle_x';
end

% decide if re-order is needed
meanWPos=nan(numel(keepWhiskerID),1);
for wNum=1:numel(keepWhiskerID)
    meanWPos(wNum)=nanmean([wData([wData.label]==keepWhiskerID(wNum)).(fol_axis)]); %,...nanstd([wData([wData.label]==wNum).follicle_y])]
end
[~,currOrder]=sort(meanWPos);

orderingDir='ascend';
switch whiskerpad(1).ProtractionDirection
    case {'upward','leftward'}
        % intended order: min first
        if all(diff(currOrder)<0); orderingDir='descend'; end
    case {'downward','rightward'}
        if all(diff(currOrder)>0); orderingDir='descend'; end
end

% add whiskers from wid to label, for frames where those frequent whiskers are missing
allFIDs=[wData.fid]';
frameBlockSize=[diff([1;find(diff(allFIDs))+1]);numel(allFIDs)-find(diff(allFIDs),1,'last')];
allWLabels=mat2cell([wData.label]',frameBlockSize);
allWID=mat2cell([wData.wid]',frameBlockSize);
orderingVals=mat2cell([wData.(fol_axis)]',frameBlockSize);

parfor fID=1:numel(ufIds)
    if any(~ismember(keepWhiskerID,allWLabels{fID}))
        % get labels from wid
        keepFWIDidx=ismember(allWID{fID},keepWhiskerID) |...
                    ismember(allWLabels{fID},keepWhiskerID);
        % sort them
        fWOrderVals=orderingVals{fID}(keepFWIDidx);
        [~,fWOrder]=sort(fWOrderVals,orderingDir);
        % make sure not to keep more values than max number of whiskers        
        if numel(fWOrder)>numel(keepWhiskerID)
            applyID=[keepWhiskerID, ones(1, numel(fWOrder)-numel(keepWhiskerID))*-1];
        else
            applyID=keepWhiskerID;
        end
        % assign values
        allWLabels{fID}(keepFWIDidx)=applyID(fWOrder);
    end
end

% assign label values
newLabels=num2cell(vertcat(allWLabels{:}));
[wData.label]=newLabels{:};

%% re-order based on follicle location
% get values
folPos=[wData.(fol_axis)];
wFPos=nan(numel(ufIds),numel(keepWhiskerID));
for wNum=1:numel(keepWhiskerID)
    wFPos(ismember(ufIds,[wData([wData.label]==keepWhiskerID(wNum)).fid]),wNum)=...
        folPos([wData.label]==keepWhiskerID(wNum));
end
wFPos= fillmissing(wFPos,'linear');
% sort and allocate
[~,sortIDx]=sort(wFPos,2);
reIdxLabels=keepWhiskerID(sortIDx);
[reIwLabels,reIwIdx]=deal(cell(numel(keepWhiskerID),1));
for wNum=1:numel(keepWhiskerID)
    reIwLabels{wNum}=num2cell(reIdxLabels(ismember(ufIds,[wData([wData.label]==...
        keepWhiskerID(wNum)).fid]),wNum));
    reIwIdx{wNum}=find([wData.label]==keepWhiskerID(wNum));
end
reIwLabels=vertcat(reIwLabels{:}); reIwIdx=[reIwIdx{:}];
try
[wData(reIwIdx).label]=reIwLabels{:};
catch
    reIwLabels;
end

%swap id and labels
labels=num2cell([wData.label]);
wIDs=num2cell([wData.wid]);
[wData.label]=wIDs{:};
[wData.wid]=labels{:};


%% Figures
if false
    
    video=VideoReader([w.FileName(1:end-24) '-' w.FileName(end-23:end-11) 'Trial50.mp4']);
    vidFrame = readFrame(video);
    figure; hold on
    image(vidFrame); set(gca, 'YDir', 'reverse');
    
    rectangle('Position',whiskerpad.Coordinates,'EdgeColor','w')
    
    plot([wData.follicle_x(~blacklist)],[wData.follicle_y(~blacklist)],'.')
    plot([wData.tip_x(~blacklist)],[wData.tip_y(~blacklist)],'x')
    
    figure;clf;
    hold on;
    for wNum=1:numel(keepWhiskerIDs)
        plot(wData.fid(wData.label==keepWhiskerIDs(wNum)),...
            wData.angle(wData.label==keepWhiskerIDs(wNum)))
    end
    
    figure; hold on
    wNum=1;
    plot(wData.fid(wData.wid==keepWhiskerIDs(wNum)),...
        wData.angle(wData.wid==keepWhiskerIDs(wNum)))
    plot(wData.fid(wData.label==keepWhiskerIDs(wNum)),...
        wData.angle(wData.label==keepWhiskerIDs(wNum)))
    plot(wData.fid(wData.widfixed==keepWhiskerIDs(wNum)),...
        wData.angle(wData.widfixed==keepWhiskerIDs(wNum)))
    
    figure;clf;
    hold on;
    for wNum=1:2 %numel(keepWhiskerIDs)
        plot(wData.fid(wData.widfixed==keepWhiskerIDs(wNum)),...
            wData.follicle_x(wData.widfixed==keepWhiskerIDs(wNum)))
    end
end
