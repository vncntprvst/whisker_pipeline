classdef WhiskingFun
    methods(Static)
        
        %% Delineate whisker pad region on first video frame
        function [whiskingParams,splitUp]=DrawWhiskerPadROI(vid)
            vidFrame = readFrame(vid); vidFrame=rgb2gray(vidFrame);
            figure; image(vidFrame);
            set(gcf, 'position', [450   571   560   420])

            % Ask if video needs to be split
            splitUp = questdlg('Do you need to split the video?', ...
                'Video splitting', 'Yes','No','No');
            close(gcf);
            switch splitUp
                case 'No'
                    % get whisker pad coordinates
                    % get whisking parameters
                    whiskingParams = WhiskingFun.GetWhiskingParams(vidFrame);
                    %clearvars firstVideo
                case 'Yes'
                    midWidth=round(size(vidFrame,2)/2);
                    % get whisking parameters for left side
                    leftImage=vidFrame(:,1:midWidth,:);
                    whiskingParams = WhiskingFun.GetWhiskingParams(leftImage);
                    % get whisking parameters for right side
                    rightImage=vidFrame(:,midWidth+1:end,:);
                    whiskingParams(2) = WhiskingFun.GetWhiskingParams(rightImage);
            end
        end
        
        %% Get whisker pad coordinates
        function [wpCoordinates,wpLocation,wpRelativeLocation,sideBrightness] =...
                GetWhiskerPadCoord(topviewImage)
            figure('Name','Draw rectangle around whisker pad','NumberTitle','off'); image(topviewImage);
            set(gcf, 'position', [500   500   size(topviewImage,2) size(topviewImage,1)])
            wpAttributes = drawrectangle('Label','align',...
                'LabelVisible','hover','Rotatable',true); %wpAttributes = drawassisted;
            WaitForROI(wpAttributes);
            wpPosition = wpAttributes.Position;
            wpLocation = round([wpPosition(1)+wpPosition(3)/2,...
                wpPosition(2)+wpPosition(4)/2]);
            wpRelativeLocation = [wpLocation(1)/(size(topviewImage,2)),...
                wpLocation(2)/size(topviewImage,1)];
            wpCoordinates=round(wpAttributes.Vertices);
            
            %rotate image and ROI to get whisker-pad-centered image
            topviewImage_r=imrotate(topviewImage,-wpAttributes.RotationAngle,'bilinear','crop');
            imageCenter=floor(wpAttributes.Parent.CameraPosition(1:2));
            center = repmat(imageCenter', 1, size(wpCoordinates,1));
            theta = deg2rad(wpAttributes.RotationAngle); 
            rot = [cos(theta) -sin(theta); sin(theta) cos(theta)];
            wpCoordinates_r= round(rot*(wpCoordinates' - center) + center)';
%             figure; imshow(topviewImage_r);
%             patch(wpCoordinates_r(:,1),wpCoordinates_r(:,2),'red','FaceColor','none')
            
%           get rotated ROI image
%           if using position: x,y,width,height
%             wpImage=squeeze(topviewImage_r(wpCoordinates_r(2):wpCoordinates_r(2)+...
%                 wpCoordinates_r(4),wpCoordinates_r(1):wpCoordinates_r(1)+wpCoordinates_r(3),1));
            wpCoordinates_r(wpCoordinates_r<=0)=1;
            wpImage=squeeze(topviewImage_r(wpCoordinates_r(1,2):wpCoordinates_r(2,2),...
                wpCoordinates_r(2,1):wpCoordinates_r(3,1),1));
            
            % find brightness ratio for each dimension
            sideBrightness.top_bottom_ratio=sum(wpImage(1,:))/sum(wpImage(end,:));
            sideBrightness.left_right_ratio=sum(wpImage(:,1))/sum(wpImage(:,end));
     
            close(gcf);
        end
        
        %% Get whisker pad parameters
        function [faceSideInImage,protractionDirection,linkingDirection]=...
                GetWhiskerPadParams(wpCoordinates,wpRelativeLocation,sideBrightness)
            switch pdist(wpCoordinates([1,2],:))/pdist(wpCoordinates([2,3],:)) < 1
                case true % Horizontal orientation
%                     if (wpRelativeLocation(2) > 0.5 && sideBrightness.top_bottom_ratio < 1) ||...
%                             (wpRelativeLocation(2) < 0.5 && sideBrightness.top_bottom_ratio > 1)
%                         disp('failed detecting whisker pad orientation')
%                         return
%                     end
                    switch sideBrightness.top_bottom_ratio > 1 %wpRelativeLocation(2) > 0.5
                        case true
                            faceSideInImage =  'bottom';
                        case false
                            faceSideInImage =  'top';
                    end
                    switch sideBrightness.left_right_ratio > 1
                        case true
                            protractionDirection = 'leftward';
                        otherwise
                            protractionDirection = 'rightward';
                    end
                case false % Vertical orientation
%                     if (wpRelativeLocation(1) > 0.5 && sideBrightness.left_right_ratio < 1) ||...
%                             (wpRelativeLocation(1) < 0.5 && sideBrightness.left_right_ratio > 1)
%                         disp('failed detecting whisker pad orientation')
%                         return
%                     end
                    switch sideBrightness.left_right_ratio > 1 %wpRelativeLocation(1) > 0.5 
                        case true
                            faceSideInImage =  'right';
                        case false
                            faceSideInImage =  'left';
                    end
                    switch sideBrightness.top_bottom_ratio > 1
                        case true
                            protractionDirection = 'upward';
                        otherwise
                            protractionDirection = 'downward';
                    end
            end
            linkingDirection = 'rostral';
        end
        
        %% Get general whisking parameters
        function whiskingParams = GetWhiskingParams(topviewImage)
            [wpCoordinates,wpLocation,wpRelativeLocation,sideBrightness] = WhiskingFun.GetWhiskerPadCoord(topviewImage);
            [faceSideInImage,protractionDirection,linkingDirection]=WhiskingFun.GetWhiskerPadParams...
                (wpCoordinates,wpRelativeLocation,sideBrightness);
            whiskingParams=struct('Coordinates',round(wpCoordinates,2),...
                'Location',wpLocation,...
                'RelativeLocation',round(wpRelativeLocation,2),...
                'FaceSideInImage',faceSideInImage,...
                'ProtractionDirection',protractionDirection,...
                'LinkingDirection',linkingDirection,...
                'ImageDimensions',size(topviewImage));
        end
        
        %% Save whisking parameters in json file
        function SaveWhiskingParams(whiskingParams,trackingDir)
            str=strrep(jsonencode(whiskingParams),',"',sprintf(',\r\n\t"'));
            str=regexprep(str,'(?<={)"','\r\n\t"');
            str=regexprep(str,'"(?=})','"\r\n');
            str=regexprep(str,'](?=})',']\r\n');
            fid = fopen(fullfile(trackingDir,'whiskerpad.json'),'w');
            fprintf(fid,'%s',str);
            fclose(fid);
        end
        
        %% Exclude objects outside whisker pad
        function [wData,blacklist]=RestrictToWhiskerPad(wData,whiskerpadCoords,ImageDim)
            % set exclusion list
            if numel(whiskerpadCoords)==4 %simple rectangular ROI x, y, width, height
                blacklist = [ wData.follicle_x ] > whiskerpadCoords(1)+whiskerpadCoords(3) | ...
                    [ wData.follicle_x ] < whiskerpadCoords(1) | ...
                    [ wData.follicle_y ] > whiskerpadCoords(2)+whiskerpadCoords(4) | ...
                    [ wData.follicle_y ] < whiskerpadCoords(2);
            elseif numel(whiskerpadCoords)>=8 % ROI Vertices (x,y)n
                wpMask = poly2mask(whiskerpadCoords(:,1),whiskerpadCoords(:,2),ImageDim(1),ImageDim(2));
%                 figure; imshow(wpMask)
                follIdx=arrayfun(@(x,y) sub2ind(ImageDim(1:2),max([round(y), 1]),max([round(x), 1])),... %make sure indices are >0
                    [wData.follicle_x],[wData.follicle_y]);
                blacklist=~ismember(follIdx,find(wpMask));
            end
            blacklist=blacklist';
            %restrict to whisker pad region
            wData = wData(~blacklist,:);
        end
        
        %% Cluster whiskers
        function wCluster = ClusterWhiskers(whiskerData)
%             wLengths=[whiskerData.length]';
%             [cluster_ids,cluster_centroids,~,cluster_distances] = ...
%                 kmeans(wLengths,2,'Distance','sqEuclidean');
            
            [cluster_ids,cluster_centroids,~,cluster_distances] = ...
                kmeans([whiskerData.length]',... whiskerData.follicle_x;whiskerData.follicle_y
                2,'Distance','sqEuclidean');
            wClusterID=find(cluster_centroids(:,1)==max(cluster_centroids(:,1)));
            wCluster=cluster_ids==wClusterID;      
            
            % unique([whiskerData(wCluster).label])
            % wCluster(~ismember(find(wCluster),faa))
        end
        
        %% Filter whisking traces
        %%%%%%%%%%%%%%%%%%%%%%%%%
        function LP_whiskerTrace=LowPassBehavData(whiskerTrace,samplingRate,threshold)
            if nargin==1
                samplingRate=1000;
            elseif nargin==2
                threshold=20;
            end
            for whiskerTraceNum=1:size(whiskerTrace,1)
                LP_whiskerTrace(whiskerTraceNum,:)=...
                    FilterTrace(whiskerTrace(whiskerTraceNum,:),samplingRate,threshold,'low'); %set-point
            end
            % figure; hold on
            % plot(whiskerTrace_ms(whiskerTraceNum,:)); plot(LP_whiskerTrace_ms(whiskerTraceNum,:),'LineWidth',2)
        end
        
        function BP_whiskerTrace=BandPassBehavData(whiskerTrace,samplingRate,threshold)
            if nargin==1
                samplingRate=1000; threshold=[4 30];
            elseif nargin==2
                threshold=[4 30];
            end
            for whiskerTraceNum=1:size(whiskerTrace,1)
                BP_whiskerTrace(whiskerTraceNum,:)=...
                    FilterTrace(whiskerTrace(whiskerTraceNum,:),samplingRate,threshold,'bandpass'); %whisking
                % figure; hold on %plot(foo) % plot(whiskerTrace_ms(whiskerTraceNum,:))
                % plot(whiskerTrace_ms(whiskerTraceNum,:)-mean(whiskerTrace_ms(whiskerTraceNum,:))); plot(BP_whiskerTrace_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        
        function HP_whiskerTrace=HighPassBehavData(whiskerTrace,samplingRate,threshold)
            if nargin==1
                samplingRate=1000;
            elseif nargin==2
                threshold=0.3;
            end
            for whiskerTraceNum=1:size(whiskerTrace,1)
                HP_whiskerTrace(whiskerTraceNum,:)=...
                    FilterTrace(whiskerTrace(whiskerTraceNum,:),samplingRate,threshold,'high')'; %whisking
                % plot(HP_whiskerTrace_ms(whiskerTraceNum,:),'LineWidth',1)
            end
        end
        
        %% Adjust whisker angle to match convention
        % See Towal et al 2011 https://journals.plos.org/ploscompbiol/article/figure?id=10.1371/journal.pcbi.1001120.g007
        function angles=AngleConvention(angles, whiskerpad)
            % check for horizontal face position 
            switch whiskerpad.FaceSideInImage
                case 'right' 
                    angles=-angles; %invert sign
            end
            switch whiskerpad.ProtractionDirection
                case 'downward'
                    angles=(180-angles); % flip 0 to 180 coordinates
            end
        end
        %% ResampleBehavData
        %%%%%%%%%%%%%%%%%%%%
        function whiskerTrace_ms=ResampleBehavData(whiskerTrackingData,vidTimes,samplingRate)
            %resample to 1ms precision
            vidTimes_ms=vidTimes/samplingRate*1000;
            for whiskerTraceNum=1:size(whiskerTrackingData,1)
                % Create array with angle values and time points
                whiskerTrace_ms(whiskerTraceNum,:)=interp1(vidTimes_ms,whiskerTrackingData(whiskerTraceNum,:),...
                    vidTimes_ms(1):vidTimes_ms(end));
                % [whiskerTrace(:,1),whiskerTrace(:,2)] = resample(whiskerTrace(:,1),whiskerTrace(:,2),'pchip');
            end
            % figure; plot(whiskerTrace_ms(whiskerTraceNum,:));
        end
        
        %% FindPeakWhisking
        %%%%%%%%%%%%%%%%%%%
        function peakWhisking=FindPeakWhisking(whiskerTrace_ms)
            % Find a period with whisking bouts
            % no need to keep periods with no whisking
            % figure; plot(whiskerTrace); % select data point and export cursor info
            % whiskingPeriod=1:cursor_info.Position(1); %in ms
            for whiskerTraceNum=1:size(whiskerTrace_ms,1)
                peakWhisking(whiskerTraceNum,:)=[0 0 diff(cummax(abs(diff(whiskerTrace_ms(whiskerTraceNum,:)))))];
                % peakWhiskingIdx=find(peakWhisking_ms==max(peakWhisking_ms));
                % whiskingPeriod=peakWhiskingIdx-5000:peakWhiskingIdx+4999; %in ms
            end
        end
        
        %% GetAmplitude
        %%%%%%%%%%%%%%%
        function wAmplitude=GetAmplitude(wTraces,wPhase)
            % Use function from J. Aljadeff, B.J. Lansdell, A.L. Fairhall and D. Kleinfeld (2016) Neuron, 91
            % link to manuscript: http://dx.doi.org/10.1016/j.neuron.2016.05.039
            % define functions
            Amp_Fun  = @range ; % function describing the magnitude of amplitude
            % get values
            wAmplitude = WhiskingFun.FindExtrema(wTraces,wPhase,Amp_Fun);
        end
        
        %% GetSetPoint
        %%%%%%%%%%%%%%
        function setPoint=GetSetPoint(wTraces,wPhase)
            % Use function from J. Aljadeff, B.J. Lansdell, A.L. Fairhall and D. Kleinfeld (2016) Neuron, 91
            % link to manuscript: http://dx.doi.org/10.1016/j.neuron.2016.05.039
            % define functions
            SetPoint_Fun =  @(x) (max(x) + min (x)) / 2'; % function describing the setpoint location
            % get values
            setPoint = WhiskingFun.FindExtrema(wTraces,wPhase,SetPoint_Fun);
        end
        
        %% FindExtrema
        %%%%%%%%%%%%%%
        function [interpSig, peakIdx, troughIdx] = FindExtrema(whiskerTrace, whiskerPhase, operation)
            % Use the phase (p) to find the turning points of the whisks (tops and
            % bottoms), and calculate a value on each consecutive whisk using the
            % function handle (operation, e.g. for amplitude, Amp_Fun  = @range)
            % The values are calculated twice per whisk cycle using both
            % bottom-to-bottom and top-to-top.  The values are linearly
            % interpolated between whisks.
            % From Primer code > get_slow_var
            % https://github.com/NeuroInfoPrimer/primer.git
            % find crossings
            peakIdx = find(whiskerPhase(1:end-1)<0 & whiskerPhase(2:end)>=0);
            troughIdx = find(whiskerPhase(1:end-1)>=pi/2 & whiskerPhase(2:end)<=-pi/2);
            
            % evaluate at transitions
            temp = []; pos = [];
            for valNum = 2:length(peakIdx)
                vals =  whiskerTrace( peakIdx(valNum-1):peakIdx(valNum) );
                temp(end+1)  =  operation(vals);
            end
            if length(peakIdx) > 1
                pos =    round( peakIdx(1:end-1) + diff(peakIdx)/2);
            end
            for valNum = 2:length(troughIdx)
                vals =  whiskerTrace( troughIdx(valNum-1):troughIdx(valNum) );
                temp(end+1)  =  operation(vals);
            end
            if length(troughIdx) > 1
                pos   = [pos round(troughIdx(1:end-1) + diff(troughIdx)/2)];
            end
            
            % sort everything
            [pos,i] = sort(pos);
            pos = [1 pos length(whiskerTrace)];
            
            if isempty(temp)
                temp = operation( whiskerTrace ) * [1 1] ;
            else
                temp = [temp(i(1)) temp(i) temp(i(end))];
            end
            
            % make piecewise linear signal
            interpSig = zeros( [1 length(whiskerTrace)] );
            for valNum = 2:length(pos)
                in = pos(valNum-1):pos(valNum);
                interpSig(in) = linspace( temp(valNum-1), temp(valNum), length(in) );
            end
        end
        
        %% Compute Phase
        %%%%%%%%%%%%%%%%%%
        % Current code based on Whisker.WhiskerTrialLite (part of WhiskerPipeline)
        %                       > get_hilbert_transform
        %                       > get_phase
        function [whiskerPhase,whiskerFreq,whiskerAmplitude]=...
                ComputePhase(behavTrace,sampleRate,behavPeriodIdx,signalClass)
            if nargin<4 || isempty(signalClass)
                signalClass = 'whisking';
            end
            if nargin<3 || isempty(behavPeriodIdx) %% compute phase over whole trace
                behavPeriodIdx=ones(1,size(behavTrace,2));
            end
            if nargin<2 || isempty(sampleRate)
                sampleRate=500; %default video acquisition frame rate
            end
            switch signalClass
                case 'whisking'
                    % bandpass filter 8 Hz lower to 30 Hz upper
                    bandPassCutOffsInHz = [ 8,30 ];
                case 'setpoint'
                    % bandpass filter 8 Hz lower to 30 Hz upper
                    bandPassCutOffsInHz = [ 0.1,4 ];
                case 'breathing'
                    % bandpass filter 8 Hz lower to 30 Hz upper
                    bandPassCutOffsInHz = [ 0.05 ,8];
            end
                
            [whiskerPhase,whiskerFreq,whiskerAmplitude]=deal(nan(size(behavTrace)));
            for whiskerTraceNum=1:size(behavTrace,1)
                
                W1 = bandPassCutOffsInHz(1) / (sampleRate/2);
                W2 = bandPassCutOffsInHz(2) / (sampleRate/2);
                [ filtVectB, filtVectA ] = butter(2, [ W1 W2 ], 'bandpass');
                thetaNoNan = MMath.InterpNaN(behavTrace);
                filteredSignal = filtfilt(filtVectB, filtVectA, thetaNoNan);
                % Hilbert transform
                HTangleTrace = hilbert(filteredSignal)';
                % get phase from angle of complex-valued time series
                whiskerPhase(whiskerTraceNum,:) = -angle(HTangleTrace); % use -pi / pi convention
                whiskerFreq(whiskerTraceNum,:) = [0 sampleRate/(2*pi)*diff(unwrap(whiskerPhase(whiskerTraceNum,:)))];
                whiskerAmplitude(whiskerTraceNum,:) = abs(HTangleTrace);
            end
            whiskerPhase(:,~behavPeriodIdx)=nan;
            % numBins=32; % each bin = pi/16 radians
            % edges = linspace(min(whiskerPhase), max(whiskerPhase), numBins+1);
            % centers = mean([ edges(1:end-1); edges(2:end) ]);
            % [ ~, ~, phaseBins ] = histcounts(whiskerPhase, edges);
            % phaseBinCount=histcounts(phaseBins,[1 1+unique(phaseBins)]);
            % bar(unique(phaseBins),phaseBinCount)
        end
        
        % Legacy Phase calculation: fairly similar results, with overide of
        % small interwhisks, but biased toward retraction phase (rises more
        % slowly on average). See also Hill et al. 2011
        function [whiskerPhase,protractionIdx,retractionIdx]=ComputePhase_Legacy(whiskerTrace,whiskingPeriodIdx)
            if nargin==1 %% compute phase over whole trace
                whiskingPeriodIdx=ones(1,size(whiskerTrace,2));
            end
            [whiskerPhase,protractionIdx,retractionIdx]=deal(nan(size(whiskerTrace)));
            for whiskerTraceNum=1:size(whiskerTrace,1)
                % Hilbert transform NEEDS ANGLE TO BE ZERO CENTERED !
                angleTrace=whiskerTrace(whiskerTraceNum,:)-...
                    mean(whiskerTrace(whiskerTraceNum,:));
                % convert to radian if needed
                if max(abs(angleTrace))>pi
                    angleTrace=angleTrace*pi/180;
                end
                % Hilbert transform
                %                 HTangleTrace=hilbert(angleTrace); % doesn't work as expected
                % compute Fourier transform
                fftTrace=fft(angleTrace);
                % set power at negative frequencies to zero
                fftTrace(((size(fftTrace,2)+mod(size(fftTrace,2),2))/2):end)=0;
                % generate complex-valued time series via inverse Fourier transform
                HTangleTrace=ifft(fftTrace);
                % get phase from angle of complex-valued time series
                whiskerPhase(whiskerTraceNum,:)=angle(HTangleTrace);
                % identify protraction and retraction epochs
                protractionIdx(whiskerTraceNum,:)=whiskerPhase(whiskerTraceNum,:)<0;
                retractionIdx(whiskerTraceNum,:)=whiskerPhase(whiskerTraceNum,:)>0;
            end
            whiskerPhase(:,~whiskingPeriodIdx)=nan;
            %             figure; hold on; whiskerTraceNum=1;
            %             plot(whiskerTrace(whiskerTraceNum,1:100000))
            % %             plot(whiskingPeriodIdx(whiskerTraceNum,1:100000))
            %             plot(whiskerPhase_ms(whiskerTraceNum,1:100000))
            %             plot(1:100000,zeros(1,100000),'--k')
            %             protractionAngle=whiskerTrace(whiskerTraceNum,:)*pi/180;
            %             protractionAngle(~protractionIdx(whiskerTraceNum,:))=NaN;
            %             plot(protractionAngle(whiskerTraceNum,1:100000),'k')
            %             retractionAngle=whiskerTrace(whiskerTraceNum,:)*pi/180;
            %             retractionAngle(~retractionIdx(whiskerTraceNum,:))=NaN;
            %             plot(retractionAngle(whiskerTraceNum,1:100000),'r')
        end
        
        %% Find instantaneous frequency
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function instantFreq=ComputeInstFreq(whiskerTrace)
            % see also instfreq (e.g., ifq = instfreq(whiskerTrace,1000,'Method','hilbert') )
            Nfft = 1024;
            % [Pxx,f] = pwelch(BP_whiskerTrace,gausswin(Nfft),Nfft/2,Nfft,1000);
            % figure; plot(f,Pxx); ylabel('PSD'); xlabel('Frequency (Hz)'); grid on;
            for whiskerTraceNum=1:size(whiskerTrace,1)
                [~,sgFreq(:,whiskerTraceNum),sgTime(whiskerTraceNum,:),sgPower(whiskerTraceNum,:,:)] =...
                    spectrogram(whiskerTrace(whiskerTraceNum,:),gausswin(Nfft),Nfft/2,Nfft,1);
                instantFreq(whiskerTraceNum,:) = medfreq(squeeze(sgPower(whiskerTraceNum,:,:)),sgFreq(:,whiskerTraceNum));
                % figure; plot(sgTime(whiskerTraceNum,:),round(instantFreq(whiskerTraceNum,:)*1000),'linewidth',2)
            end
        end
        
        %% FindWhiskingEpochs
        %%%%%%%%%%%%%%%%%%%%%
        function whiskingEpochsIdx=FindWhiskingEpochs(wAmplitude,wFrequency,...
                ampThreshold,freqThreshold,minDur)
            if nargin<5; minDur=100; end
            if nargin<4; freqThreshold=1; end
            if nargin<3; ampThreshold=2.5; end % (degrees)
            wAmplitude(isnan(wAmplitude))=0;
            ampSmoothFiltParam = 0.005 ; % parameter for amplitude smoothing filter such that whisking bout 'cutouts' are not too short
            ampFilter = filtfilt(ampSmoothFiltParam, [1 ampSmoothFiltParam-1],wAmplitude) ; % filtered amplitude variable
            % threshold by amplitude
            ampEpochsIdx = logical(heaviside(ampFilter-ampThreshold));
            % threshold by frequency
            freqEpochsIdx = wFrequency>freqThreshold;
            whiskingEpochsIdx = ampEpochsIdx; %& freqEpochsIdx;
            if exist('minDur','var') %remove periods shorter than minimum duration
                whiskBoutList = bwconncomp(whiskingEpochsIdx) ;
                properWhiskBoutIdx=cellfun(@(wBout) numel(wBout)>=minDur, whiskBoutList.PixelIdxList);
                whiskingEpochsIdx(vertcat(whiskBoutList.PixelIdxList{~properWhiskBoutIdx}))=false;
            end
        end
        
%         ampThd=18; %12; %18 %amplitude threshold
% freqThld=1; %frequency threshold
% minBoutDur=1000; %500; % 1000 % minimum whisking bout duration: 1s
% whiskingEpochs=cell(numel(bWhisk),1);
% for wNum=1:numel(bWhisk)
%     whiskingEpochs{wNum}=WhiskingFun.FindWhiskingEpochs(...
%         whiskers(bWhisk(wNum)).amplitude,whiskers(bWhisk(wNum)).frequency,...
%         ampThd, freqThld, minBoutDur);
%     whiskingEpochs{wNum}(isnan(whiskingEpochs{wNum}))=false; %just in case
%     whiskingEpochsList=bwconncomp(whiskingEpochs{wNum});
%     [~,wBoutDurSort]=sort(cellfun(@length,whiskingEpochsList.PixelIdxList),'descend');
%     whiskingEpochsList.PixelIdxListSorted=whiskingEpochsList.PixelIdxList(wBoutDurSort);
% end
                
        %% FindWhiskingModes
        %%%%%%%%%%%%%%%%%%%
        function wMode=FindWhiskingModes(wAngle,wVelocity,wAmplitude,wFrequency,wSetPoint,samplingRate,whiskingEpochsIdx)
            % For whisking modes definition, see Berg and Kleinfeld 2003 (in rat)
            % https://physiology.org/doi/full/10.1152/jn.00600.2002
            % Four main modes:
            % foveal: high frequency > 10Hz, medium amplitude >25 <35, high setpoint/angular values >70 at start of whisk
            % exploratory: lower frequency < 10, high amplitude >35, medium setpoint/angular values ?
            % resting: lower frequency < 10Hz, low/medium amplitude <25, low setpoint/angular values <60
            % twiches: high frequency > 25Hz, low amplitude <10, low setpoint/angular values <70 at start of whisk
            whiskingMode={'hf_foveal';'mf_foveal';'exploratory';'resting';'twitching'};
            wMode=struct('type',[],'ampThd',[],'freqThd',[],'setPoint',[],'durThd',[],'index',false(1,length(wAmplitude)));
            isNanIdx=isnan(wAngle) | isnan(wVelocity) | isnan(wAmplitude) | isnan(wFrequency) | isnan(wSetPoint);
            wAngle=wAngle(~isNanIdx); wVelocity=wVelocity(~isNanIdx); wAmplitude=wAmplitude(~isNanIdx); wFrequency=wFrequency(~isNanIdx); wSetPoint=wSetPoint(~isNanIdx);
            if nargin<6; samplingRate =1000; end
            if nargin<7
                %                     smoothFiltParam = 0.005 ; % parameter for amplitude smoothing filter such that whisking bout 'cutouts' are not too short
                %                     ampFilter = filtfilt(smoothFiltParam, [1 smoothFiltParam-1],wAmplitude) ; % filtered amplitude variable
                %                     ampEpochsIdx = logical(heaviside(ampFilter-wMode(wModeN).ampThd(1))); % threshold by amplitude
                threshold = 4/(samplingRate/2);
                [coeffB,coeffA] = butter(3,threshold,'low');
                velFilter = filtfilt(coeffB, coeffA,abs(wVelocity)) ;
                velEpochsIdx = velFilter>0.2; % threshold by velocity
                whiskingEpochsIdx = velEpochsIdx; % & ampEpochsIdx;
            end
            whiskBoutList = bwconncomp(velEpochsIdx) ;
            figure; hold on; plot(wAngle)
            for wModeN=1:numel(whiskingMode)
                wMode(wModeN).type=whiskingMode{wModeN};
                switch wMode(wModeN).type
                    case 'hf_foveal'
                        wMode(wModeN).ampThd=[25 35];wMode(wModeN).freqThd=[16 Inf];wMode(wModeN).setPoint=[70 180];wMode(wModeN).durThd=500;
                    case 'mf_foveal'
                        wMode(wModeN).ampThd=[25 35];wMode(wModeN).freqThd=[10 16];wMode(wModeN).setPoint=[60 180];wMode(wModeN).durThd=500;
                    case 'exploratory'
                        wMode(wModeN).ampThd=[35 Inf];wMode(wModeN).freqThd=[4 10];wMode(wModeN).setPoint=[45 135];wMode(wModeN).durThd=500;
                    case 'resting'
                        wMode(wModeN).ampThd=[0 25];wMode(wModeN).freqThd=[0 10];wMode(wModeN).setPoint=[0 60];wMode(wModeN).durThd=500;
                    case 'twitching'
                        wMode(wModeN).ampThd=[0 10];wMode(wModeN).freqThd=[25 Inf];wMode(wModeN).setPoint=[0 70];wMode(wModeN).durThd=100;
                end
                properWhiskBoutAmpIdx=cellfun(@(wBout) any(wAmplitude(wBout)>=wMode(wModeN).ampThd(1) &...
                    wAmplitude(wBout)<=wMode(wModeN).ampThd(end)),whiskBoutList.PixelIdxList);
                properWhiskBoutFreqIdx=cellfun(@(wBout) mean(wFrequency(wBout))>=wMode(wModeN).freqThd(1) &...
                    mean(wFrequency(wBout))<=wMode(wModeN).freqThd(end),whiskBoutList.PixelIdxList);
                properWhiskBoutSetPointIdx=cellfun(@(wBout) mean(wSetPoint(wBout))>=wMode(wModeN).setPoint(1) &...
                    mean(wSetPoint(wBout))<=wMode(wModeN).setPoint(end),whiskBoutList.PixelIdxList);
                properWhiskBoutDurIdx=cellfun(@(wBout) numel(wBout)>=wMode(wModeN).durThd, whiskBoutList.PixelIdxList);
                whiskingEpochsIdx = velEpochsIdx;
                whiskingEpochsIdx(vertcat(whiskBoutList.PixelIdxList{... %~properWhiskBoutAmpIdx}))=false; %...
                    ~(properWhiskBoutDurIdx & properWhiskBoutAmpIdx &...
                    properWhiskBoutFreqIdx & properWhiskBoutSetPointIdx)}))=false;
                wMode(wModeN).index(~isNanIdx)=whiskingEpochsIdx;
                whiskModeVals=nan(size(wAngle));
                whiskModeVals(wMode(wModeN).index)=wAngle(wMode(wModeN).index);
                plot(whiskModeVals);
                
            end
        end
        
        %% Compute spectral coherence
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
    end
end

