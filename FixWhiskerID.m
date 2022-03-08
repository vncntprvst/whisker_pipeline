function wData=FixWhiskerID(wData)

% Compute centroids 
% simple version on measurements with follicles and tips 

% arrayfun(@(wVals) polyshape([wVals.follicle_x, wVals.tip_x],[wVals.follicle_y, wVals.tip_y]), wData);


%demux timeseries of whisker ids based on length and follicle
wIDs=unique([wData([wData.wid]>=0).wid]);
wFolx=[wData.follicle_x]; wFoly=[wData.follicle_y];
wIdx=[wData.wid];

% sideIdx=[wData.follicle_x]>[wData.tip_x];

figure; hold on
for wNum=1:4 %numel(wIDs)
    wFolxVals=wFolx(wIdx==wIDs(wNum));
    wFolyVals=wFoly(wIdx==wIDs(wNum));
    plot(wFolxVals,wFolyVals,'.')
end
legend(num2str(wIDs'))

See ExtractMixedSignalsExample
% C:\Users\wanglab\Documents\MATLAB\Examples\R2020b\stats\ExtractMixedSignalsExample\ExtractMixedSignalsExample.m

% Compute Euclidian distance



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
wData.widfixed=wData.wid;
for wNum=0:2
    fidList=unAllocObs(clusAlloc==wNum);
    nonRedundent_fidList=~ismember(wpMeasurements.fid(fidList),...
        wData.fid(wpIdx(wIdx==wNum)));
    fidList=fidList(nonRedundent_fidList);
    wData.label(wpIdx(fidList))=wNum;
    wData.widfixed(wpIdx(fidList))=wNum;
end

% reset frequency
[wFreq,uniqueWIDs]=hist(wData.widfixed,unique(wData.widfixed));
keepWhiskerIDs=uniqueWIDs(wFreq./numel(unique(wData.fid(wpIdx)))>0.5);


if ~isfield(wData,'widfixed')
    wData.widfixed=wData.wid;
    lwData.widfixed=lwData.wid;
end


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
