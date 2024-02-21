function thetas=WhiskerAngleSmoothFill(varargin)
%% Find angle values and convert to degrees
if nargin==1 && min(size(varargin{1}))==1%
    thetas=varargin{1};
    if max(abs(varargin{1}))==pi %orientation values in radian
        thetas=thetas*180/pi; %equivalent to rad2deg
    end
    %center to zero median
    %   thetas=thetas-nanmedian(thetas);
elseif nargin==2 %centroid values
    centroidX=varargin{1}; centroidY=varargin{2};
    %   rebase to whisker referential (mid-point termined from maxima)
    centroidX=centroidX-mean([min(centroidX) max(centroidX)]);
    centroidY=centroidY-mean([min(centroidY) max(centroidY)]);
    centroidY=centroidY-min(centroidY);
    %   convert to radian
    centroidX=centroidX/max(abs(centroidX))*pi/2;
    centroidY=centroidY/max(abs(centroidY))*pi/2;
    thetas = FindAngle(centroidX,centroidY);
elseif nargin==1 && min(size(varargin{1}))>1 % more than 1 whisker centroid values
    if numel(size(varargin{1}))==3 %variable also contains base data
        centroidValues=varargin{1}(:,:,1);
        baseValues=varargin{1}(:,:,2);
    else
        centroidValues=varargin{1};
    end
    thetas=nan(size(centroidValues,2)/2,size(centroidValues,1));
    for whiskerNum=1:2:size(centroidValues,2)
        centroidX=centroidValues(:,whiskerNum); centroidY=centroidValues(:,whiskerNum+1);
        %   rebase to whisker referential 
        if exist('baseValues','var')% use average base values
            refXVals=nanmean(baseValues(:,whiskerNum));
            refYVals=nanmean(baseValues(:,whiskerNum+1));
        else    % (mid-point determined from maxima)
            refXVals=mean([min(centroidX) max(centroidX)]);
            refYVals=mean([min(centroidY) max(centroidY)]);
        end
        centroidX=centroidX-refXVals;
        centroidY=centroidY-refYVals;
        centroidY=centroidY-min(centroidY);
        %   convert to radian
        centroidX=centroidX/max(abs(centroidX))*pi/2;
        centroidY=centroidY/max(abs(centroidY))*pi/2;
        thetas((whiskerNum+1)/2,:) = FindAngle(centroidX,centroidY);
    end
end
% find dimension
if size(thetas,2)>size(thetas,1); thetas=thetas'; end
% find and replace outliers
thetas = filloutliers(thetas,'spline','movmedian',20)';

%% smooth values
for whiskerNum=1:size(thetas,1)
    % find outliers
%     outliers=abs(thetas(whiskerNum,:))>30*mad(abs(thetas(whiskerNum,:)));
%     thetas(whiskerNum,outliers)=nan;
        % plots
    % figure; hold on; plot(thetas(whiskerNum,:))
    % plot(outliers,zeros(numel(outliers,1)),'rd')
    
    % find missing bits length
    % nanBouts=hist(bwlabel(isnan(thetas(whiskerNum,:))),unique(bwlabel(isnan(thetas(whiskerNum,:)))));
    % nanBouts=sort(nanBouts,'descend'); maxNanBouts=nanBouts(2);
    
    % smooth
    thetas(whiskerNum,:)=smoothdata(thetas(whiskerNum,:),'rloess',7);
    %linear %spline %movmedian
    %     [b,a] = butter(3,40/250,'low');
    %     foo = filtfilt(b,a,thetas(whiskerNum,:));
    
    %fill missing / NaNs values (if any)
    fillDim=find(size(thetas(whiskerNum,:))==max(size(thetas(whiskerNum,:))));
    thetas(whiskerNum,:)=fillmissing(thetas(whiskerNum,:),'spline',fillDim,'EndValues','nearest');
    % plot(thetas(whiskerNum,:))
end

function wAngle = FindAngle(centroidX,centroidY)
for i = 1:length(centroidX)
    if atan2(centroidY(i),centroidX(i))>=0
        wAngle(i) = (180/pi) * (atan2(centroidY(i),centroidX(i)));
    else
        wAngle(i) = (180/pi) * (atan2(centroidY(i),centroidX(i))+2*pi);
    end
end