function keepWhiskers=FindBestWhisker(wData,whiskerpad,side)
%% Find whiskers that are well tracked
% [wFreq,uniqueWIDs]=hist(wData.wid,unique(wData.wid));
% [keepWhiskerIDs,kwi]=deal(uniqueWIDs(wFreq./numel(unique(wData.fid))>070));

[tmpKW,keepWhiskers]=deal(struct('side',[],'whiskerIDs',[],'bestWhisker',[]));

if nargin > 1
    switch side
        case {'left','right'} % limit to one side if requested
            wpIdx={wData.whiskerPadIdx==find(contains({whiskerpad.FaceSideInImage},side))};
            side={side};
        case 'both'
            side={whiskerpad.FaceSideInImage};
            wpIdx{1}=wData.whiskerPadIdx==1;
            wpIdx{2}=wData.whiskerPadIdx==2;
    end
else
    wpIdx={1:size(wData,1)};
    side = {'undefined'};
end

% keepWhiskerIDs=cell(numel(wIdx),2);
for sideIdx=1:numel(wpIdx)
    tmpKW(sideIdx).side=side{sideIdx};
    hemi_wData=wData(wpIdx{sideIdx},:);
    [wFreq,uniqueWIDs]=hist(hemi_wData.wid,unique(hemi_wData.wid));
    tmpKW(sideIdx).whiskerIDs=uniqueWIDs(wFreq./numel(unique(hemi_wData.fid))>0.70);
    if isempty(tmpKW(sideIdx).whiskerIDs)
        tmpKW(sideIdx).whiskerIDs=uniqueWIDs(wFreq==max(wFreq));
    end
    %     %recover "good" whiskers that may have been crowded out by whiskers on the other side.
    %     keepWhiskerIDs=unique([keepWhiskerIDs;kwi]);
    
    % Find best whisker
    baseVar=nan(numel(tmpKW(sideIdx).whiskerIDs),2);
    for wNum=1:numel(tmpKW(sideIdx).whiskerIDs)
        baseVar(wNum,:)=[nanstd(hemi_wData.follicle_x(hemi_wData.wid==...
            tmpKW(sideIdx).whiskerIDs(wNum))),...
            nanstd(hemi_wData.follicle_y(hemi_wData.wid==...
            tmpKW(sideIdx).whiskerIDs(wNum)))];
    end
    baseVar=mean(baseVar,2);
    tmpKW(sideIdx).bestWhisker= tmpKW(sideIdx).whiskerIDs(baseVar==min(baseVar));
end

for sideIdx=1:numel(wpIdx)
    for wNum=1:numel(tmpKW(sideIdx).whiskerIDs)
        wIdx=wNum+((sideIdx-1)*numel(tmpKW(1).whiskerIDs));
        keepWhiskers(wIdx).side=tmpKW(sideIdx).side;
        keepWhiskers(wIdx).whiskerIDs=tmpKW(sideIdx).whiskerIDs(wNum);
        keepWhiskers(wIdx).bestWhisker=tmpKW(sideIdx).bestWhisker==keepWhiskers(wIdx).whiskerIDs;
    end
end

