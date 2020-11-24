function [keepWhiskerIDs,bestWhisker]=FindBestWhisker(wData,side)
%% Find whiskers that are well tracked
[wFreq,uniqueWIDs]=hist(wData.wid,unique(wData.wid));
[keepWhiskerIDs,kwi]=deal(uniqueWIDs(wFreq./numel(unique(wData.fid))>0.70));

%% Find best whisker
% limit to one side if requested
if nargin>1
    switch side
        case 'left'
            sideIdx=wData.follicle_x>wData.tip_x;
        case 'right'
            sideIdx=wData.follicle_x<wData.tip_x;
    end
    wData=wData(sideIdx,:);
    [wFreq,uniqueWIDs]=hist(wData.wid,unique(wData.wid));
    kwi=uniqueWIDs(wFreq./numel(unique(wData.fid))>0.70);
    %recover "good" whiskers that may have been crowded out by whiskers on the other side. 
    keepWhiskerIDs=unique([keepWhiskerIDs;kwi]); 
end

for wNum=1:numel(kwi)
    baseVar(wNum,:)=[nanstd(wData.follicle_x(wData.wid==kwi(wNum))),...
        nanstd(wData.follicle_y(wData.wid==kwi(wNum)))];
end

baseVar=mean(baseVar,2);
bestWhisker=kwi(baseVar==min(baseVar));
