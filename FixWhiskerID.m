function [wData,keepWhiskerIDs,bestWhisker]=FixWhiskerID(wData,fixData)
%% Find whiskers that are well tracked.
[wFreq,uniqueWIDs]=hist(wData.WP_Data.wid,unique(wData.WP_Data.wid));
keepWhiskerIDs=uniqueWIDs(wFreq./numel(unique(wData.WP_Data.fid))>0.75);

if nargin > 1 && fixData
    % get whisker pad parameters
    whiskerpad = jsondecode(fileread(fullfile(cd,'whiskerpad.json')));
    % set iexclusion list
    blacklist = ... %[ wData.WP_Data.length ] < whiskerLengthThresh | ...
        [ wData.WP_Data.follicle_x ] > whiskerpad.Coordinates(1)+whiskerpad.Coordinates(3) | ...
        [ wData.WP_Data.follicle_x ] < whiskerpad.Coordinates(1) | ...
        [ wData.WP_Data.follicle_y ] > whiskerpad.Coordinates(2)+whiskerpad.Coordinates(4) | ...
        [ wData.WP_Data.follicle_y ] < whiskerpad.Coordinates(2);
    
    %restrict to whisker pad region
    wpMeasurements = wData.WP_Data(~blacklist,:);
    wIdx=[wpMeasurements.label];

    %% get distance to original cluster
    initCLuster=[[wpMeasurements.follicle_x],...
        [wpMeasurements.follicle_y],...
        [wpMeasurements.tip_x],...
        [wpMeasurements.tip_y]];
    unsortedObs=initCLuster(wIdx==-1,:);
    [~,ic_comps] = pca(zscore(initCLuster));
    [~,uo_comps] = pca(zscore(unsortedObs));
    mDist2Clus=nan(size(uo_comps,1),3);
    for wNum=0:2
        %     mDist=squareform(pdist([mean(initCLuster(wIdx==wNum,:));unsortedObs]));
        %     mDist2Clus(:,wNum+1)=mDist(2:end,1);
        mDist=pdist([mean(ic_comps(wIdx==wNum,:));uo_comps]); %squareform
        mDist2Clus(:,wNum+1)=mDist(1:size(uo_comps,1)); %mDist(2:end,1);
    end
    clusAlloc=mod(find((mDist2Clus==min(mDist2Clus,[],2))'),3)';
    clusAlloc(clusAlloc==0)=3; clusAlloc=clusAlloc-1;
    
    % plot outcome
    %     figure; hold on
    %     image(vidFrame); set(gca, 'YDir', 'reverse');
    %     for wNum=0:2
    %         plot([unsortedObs(clusAlloc==wNum,1)],[unsortedObs(clusAlloc==wNum,2)],'.')
    %         plot([unsortedObs(clusAlloc==wNum,3)],[unsortedObs(clusAlloc==wNum,4)],'x')
    %     end
    
    %% allocate to frames that need it
    unAllocObs=find(wIdx==-1);
    wpIdx=find(~blacklist);
    wData.WP_Data.widfixed=wData.WP_Data.wid;
    for wNum=0:2
        fidList=unAllocObs(clusAlloc==wNum);
        nonRedundent_fidList=~ismember(wpMeasurements.fid(fidList),...
            wData.WP_Data.fid(wpIdx(wIdx==wNum)));
        fidList=fidList(nonRedundent_fidList);
        wData.WP_Data.label(wpIdx(fidList))=wNum;
        wData.WP_Data.widfixed(wpIdx(fidList))=wNum;
    end
    
    % reset frequency 
    [wFreq,uniqueWIDs]=hist(wData.WP_Data.widfixed,unique(wData.WP_Data.widfixed));
    keepWhiskerIDs=uniqueWIDs(wFreq./numel(unique(wData.WP_Data.fid(wpIdx)))>0.5);

end
if ~isfield(wData.WP_Data,'widfixed')
    wData.WP_Data.widfixed=wData.WP_Data.wid;
end
for wNum=1:numel(keepWhiskerIDs)
    baseVar(wNum,:)=[nanstd(wData.WP_Data.follicle_x(wData.WP_Data.widfixed==keepWhiskerIDs(wNum))),...
        nanstd(wData.WP_Data.follicle_y(wData.WP_Data.widfixed==keepWhiskerIDs(wNum)))];
end
baseVar=mean(baseVar,2);
bestWhisker=baseVar==min(baseVar);


%% Figures
if false
    
    video=VideoReader([w.FileName(1:end-24) '-' w.FileName(end-23:end-11) 'Trial50.mp4']);
    vidFrame = readFrame(video);
    figure; hold on
    image(vidFrame); set(gca, 'YDir', 'reverse');
    
    rectangle('Position',whiskerpad.Coordinates,'EdgeColor','w')
    
    plot([wData.WP_Data.follicle_x(~blacklist)],[wData.WP_Data.follicle_y(~blacklist)],'.')
    plot([wData.WP_Data.tip_x(~blacklist)],[wData.WP_Data.tip_y(~blacklist)],'x')
    
    figure;clf;
    hold on;
    for wNum=1:numel(keepWhiskerIDs)
        plot(wData.WP_Data.fid(wData.WP_Data.label==keepWhiskerIDs(wNum)),...
            wData.WP_Data.angle(wData.WP_Data.label==keepWhiskerIDs(wNum)))
    end
    
    figure; hold on
    wNum=1;
    plot(wData.WP_Data.fid(wData.WP_Data.wid==keepWhiskerIDs(wNum)),...
            wData.WP_Data.angle(wData.WP_Data.wid==keepWhiskerIDs(wNum)))
    plot(wData.WP_Data.fid(wData.WP_Data.label==keepWhiskerIDs(wNum)),...
            wData.WP_Data.angle(wData.WP_Data.label==keepWhiskerIDs(wNum)))
    plot(wData.WP_Data.fid(wData.WP_Data.widfixed==keepWhiskerIDs(wNum)),...
            wData.WP_Data.angle(wData.WP_Data.widfixed==keepWhiskerIDs(wNum)))
    
    figure;clf;
    hold on;
    for wNum=1:2 %numel(keepWhiskerIDs)
        plot(wData.WP_Data.fid(wData.WP_Data.widfixed==keepWhiskerIDs(wNum)),...
            wData.WP_Data.follicle_x(wData.WP_Data.widfixed==keepWhiskerIDs(wNum)))
    end
end
