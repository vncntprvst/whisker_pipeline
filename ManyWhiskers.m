classdef ManyWhiskers < PipelineBaseClass
    %MANYWHISKERSBATCH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        todoStruct;
        firstRun = true;
        arm;
        pole;
        kappaParam = 0;
        faceSideInImage;
        protractionDirection;
    end
    
    properties(Dependent)
        whiskerID
        readyBar
        readyContact
    end
    
    methods
        function val = get.whiskerID(this)
            if isa(this.pipressObj, 'Pipress')
                try
                    val = unique(this.pipressObj.pipress.whiskerID);
                catch
                    val = unique(cell2mat(this.pipressObj.pipress.whiskerID));
                end
                val(isnan(val)) = [];
                val = val(:)';
            else
                val = [];
            end
        end
        function val = get.readyBar(this)
            val = (~isempty(this.arm) && ~isempty(this.pole)) || ~this.todoStruct.bar;
        end
        function val = get.readyContact(this)
            val = isa(this.classifier, 'TreeBagger') || ~this.todoStruct.contact;
        end
    end
    
    methods
        % Constructor
        function this = ManyWhiskers(varargin)
            % Handles user inputs
            p = inputParser();
            p.addRequired('mainFolder', @(x) exist(x, 'dir'));
            p.addParameter('sessionDictPath', '', @(x) exist(x, 'file'));
            p.addParameter('sessionDictEntryIdx', NaN, @isnumeric);
            
            p.addParameter('measurements', true, @islogical);
            p.addParameter('bar', true, @islogical);
            p.addParameter('facemasks', true, @islogical);
            p.addParameter('physics', true, @islogical);
            p.addParameter('contact', true, @islogical);
            p.parse(varargin{:});
            
            this.mainFolder = p.Results.mainFolder;
            sessionDictPath = p.Results.sessionDictPath;
            sessionDictEntryIdx = p.Results.sessionDictEntryIdx;
            
            this.todoStruct = p.Results;
            this.todoStruct = rmfield(this.todoStruct, { 'mainFolder', 'sessionDictPath', 'sessionDictEntryIdx'});
            
            % Integrate into user input later
            this.faceSideInImage = 'bottom';
            this.protractionDirection = 'leftward';
            
            % Initialization
            this.SetupPipress(sessionDictPath, sessionDictEntryIdx);
            
            try
                whiskerIdList = cell2mat(this.pipress.whiskerID);
            catch
                whiskerIdList = this.pipress.whiskerID;
            end
            if iscell(whiskerIdList) || ~isvector(whiskerIdList)
                error('Whisker ID in pipress is illegal. Please make sure multiple IDs are not present in single trials.');
            end
            
            if this.todoStruct.bar
                this.LoadTemplates(fullfile(this.mainFolder, 'pole_template.mat'));
            end
            
            if this.todoStruct.physics
                this.LoadKappaParam(fullfile(this.mainFolder, 'kappa_param.mat'));
            end
            
            if this.todoStruct.contact
                this.LoadClassifier(fullfile(this.mainFolder, 'classifier.mat'));
            end
        end
        
        function LoadTemplates(this, templatePath)
            try
                load(templatePath);
                this.arm = arm;
                this.pole = pole;
            catch
                warning('Failed to load templates!');
            end
        end
        
        function LoadKappaParam(this, kpPath)
            try
                load(kpPath);
                this.kappaParam = kappa_param;
            catch
                warning('kappa_param.mat or kappa_param variable not found. 0 baseline kappa will be used!');
            end
        end
        
        
        
        % Processing
        function val = IsReady(this)
            if ~this.readyBar
                choice = questdlg('Templates are not loaded. Do you want to skip bar detection?', 'Missing Info', 'Yes');
                if strcmp(choice, 'Yes')
                    this.todoStruct.bar = false;
                end
            end
            if ~this.readyContact
                choice = questdlg('The classifier is not loaded. Do you want to skip contact detection?', 'Missing Info', 'Yes');
                if strcmp(choice, 'Yes')
                    this.todoStruct.contact = false;
                end
            end
            val = this.readyBar && this.readyContact;
        end
        
        function Start(this)
            if ~this.IsReady()
                msgbox('Have not specified all necessarity information!', 'Not Ready');
            else
                % Configures and starts parpool
                try
                    parpool('local');
                catch
                    disp('Using existing parallel session...');
                end
                
                try
                    % Prepares parallel processing
                    pipressSlices = this.pipressObj.Slice();
                    pkg.firstRun = this.firstRun;
                    pkg.todoStruct = this.todoStruct;
                    pkg.arm = this.arm;
                    pkg.pole = this.pole;
                    pkg.barGalleryFolder = this.barGalleryFolder;
                    pkg.kappaParam = this.kappaParam;
                    pkg.classifier = this.classifier;
                    pkg.faceSideInImage = this.faceSideInImage;
                    pkg.protractionDirection = this.protractionDirection;
                    
                    % Parallel processing
                    pipressSlices = this.ParForLoop(pipressSlices, pkg);
                    
                    % Wraps up and saves
                    this.pipressObj.Stack(pipressSlices);
                    this.pipressObj.Save(this.pipressPath);
                    disp('Done!');
                catch e
                    try
                        % Saves the exception
                        save('latestException.mat', 'e');
                        
                        % Wraps and saves
                        this.pipressObj.Stack(pipressSlices);
                        this.pipressObj.Save(this.pipressPath);
                        
                        error('Please check the lastestException.mat file for futher error info.');
                    catch
                        % nothing more can do
                    end
                end
            end
        end
        
        function pipressSlices = ParForLoop(~, pipressSlices, pkg)
            % Keywords for bypassing a processing stage
            bypassKeywords = { '^computed', '^skip', '^error', '^curated' };
            
            parfor i = 1 : length(pipressSlices)
                disp(i); % Shows the index of trial to be processed
                
                if ~isnan(pipressSlices{i}.whiskerID{1}) % makes sure whisker ID is found
                    % Initialize OneWhisker object
                    targetFile = fullfile(pipressSlices{i}.dir{1}, [ pipressSlices{i}.trialName{1}, '.measurements' ]);
                    owObj = OneWhisker(...
                        'path', targetFile, ...
                        'silent', true, ...
                        'whiskerID', pipressSlices{i}.whiskerID{1}, ...
                        'distToFace', pipressSlices{i}.distToFace{1}, ...
                        'polyRoiInPix', pipressSlices{i}.whiskerRoi{1}, ...
                        'rInMm', pipressSlices{i}.r{1}, ...
                        'baselineKappaParam', pkg.kappaParam, ...
                        'whiskerLengthInMm', pipressSlices{i}.whiskerLength{1}, ...
                        'whiskerRadiusAtBaseInMicron', pipressSlices{i}.whisBaseRadius{1}, ...
                        'faceSideInImage', pkg.faceSideInImage, ...
                        'protractionDirection', pkg.protractionDirection);
                    
                    % Fill in previous progress of this trial
                    if ~pkg.firstRun
                        owObj.checkTable.status = pipressSlices{i}{1, Pipress.GetStatusRange}';
                        owObj.checkTable.report = pipressSlices{i}{1, Pipress.GetReportRange}';
                    end
                    
                    % Linking
                    status = pipressSlices{i}.measurements{1};
                    if pkg.todoStruct.measurements && ~StringTool.MatchRegExps(status, bypassKeywords)
                        owObj.LinkWhiskers('Force', true);
                    end
                    
                    % Bar detection
                    status = pipressSlices{i}.bar{1};
                    if pkg.todoStruct.bar && ~StringTool.MatchRegExps(status, bypassKeywords)
                        owObj.DetectBar('Force', true, ...
                            'Arm', pkg.arm, ...
                            'Pole', pkg.pole, ...
                            'PosImgDir', pkg.barGalleryFolder);
                    end
                    
                    % Make masks
                    status = pipressSlices{i}.facemasks{1};
                    if pkg.todoStruct.facemasks && ~StringTool.MatchRegExps(status, bypassKeywords) && ...
                            ~isnan(pipressSlices{i}.distToFace{1})
                        owObj.MakeMasks('Force', true);
                    end
                    
                    % Compute physical quantities
                    status = pipressSlices{i}.physics{1};
                    if pkg.todoStruct.physics && ~StringTool.MatchRegExps(status, bypassKeywords)
                        owObj.DoPhysics('Force', true);
                    end
                    
                    % Detect contacts
                    status = pipressSlices{i}.contacts{1};
                    if pkg.todoStruct.contact && ~StringTool.MatchRegExps(status, bypassKeywords)
                        owObj.DetectContacts(pkg.classifier);
                    end
                    
                    % Finish OneWhisker processing
                    pipressSlices{i}{1, Pipress.GetTrialInfoRange} = [ owObj.checkTable.status', owObj.checkTable.report' ];
                    delete(owObj);
                end
            end
        end
        
        
        
        % Changes facemask offset
        function ChangeFacemaskOffset(this, oldVal, newVal)
            for i = 1 : size(this.pipress, 1)
                fmPath = fullfile(this.pipress.dir{i}, [this.pipress.trialName{i} '.facemasks']);
                if exist(fmPath, 'file')
                    load(fmPath, '-mat');
                    
                    if isempty(oldVal) && exist('currentOffset', 'var')
                        oldVal = currentOffset;
                    end
                    
                    data_faceMasks = Masquerade.Offset(data_faceMasks, oldVal, newVal);
                    currentOffset = newVal;
                    save(fmPath, 'data_faceMasks', 'currentOffset');
                end
            end
        end
        
        % Finds parameters for physics
        function [ pixelWhisRoi, r_in_mm ] = GetPhysParam(this, varargin)
            % 1) the farther r the better;
            % 2) r is constrained by the maximal distal roi boundary or bar position, whichever is closer;
            
            % Parameters
            p = inputParser();
            p.addParameter('proximalRoi', 1, @isnumeric);
            p.addParameter('minDistalRoi', 4, @isnumeric);
            p.addParameter('maxDistalRoi', 6, @isnumeric);
            p.addParameter('minBarToRoi', 1, @isnumeric);
            p.addParameter('rToDistalRoi', 0.5, @isnumeric);
            p.parse(varargin{:});
            
            pxPerMm = 32.55;
            proximalRoi = round(p.Results.proximalRoi * pxPerMm);           % from facemask
            minDistalRoi = round(p.Results.minDistalRoi * pxPerMm);         % from facemask
            maxDistalRoi = round(p.Results.maxDistalRoi * pxPerMm);         % from facemask
            minBarToRoi = round(p.Results.minBarToRoi * pxPerMm);           % room for errors like moving whisker pad
            rToDistalRoi = round(p.Results.rToDistalRoi * pxPerMm);
            
            % Find eligible trials with and without bar position, respectively
            barMask = false(size(this.pipress, 1),1);
            noBarMask = false(size(this.pipress, 1),1);
            
            for i = 1 : size(this.pipress, 1)
                if any(strcmp(this.pipress.facemasks{i}, {'computed', 'found'})) ...
                    && any(strcmp(this.pipress.bar{i}, {'curated'}))
                    barMask(i) = true;
                end
                
                if any(strcmp(this.pipress.facemasks{i}, {'computed', 'found'})) ...
                    && any(strcmp(this.pipress.bar{i}, {'curated: error no bar'}))
                    noBarMask(i) = true;
                end
            end
            barInd = find(barMask);
            pipressWithBar = this.pipress(barMask,:);
            
            
            % Computing parameters
            if ~any(barMask) && ~any(noBarMask)
                msgbox('None of the trials is eligible for computing physical parameters!', 'Error');
            else
                if any(barMask)
                    % Determine parameters using trials with bar positions
                    
                    % Find distances from poles to follicals for each trial
                    fm = pipressWithBar.facemasks_r;
                    wid = pipressWithBar.whiskerID;
                    pPos = cell2mat(cellfun(@(x) x.coordinate(1,:), pipressWithBar.bar_r, 'UniformOutput', false));
                    for i = size(pPos,1) : -1 : 1
                        % Equal follical interval approximation
                        if wid{i} <= 4
                            numPt = 4 + 1 + 2;
                        else
                            numPt = wid{i} + 1 + 2;
                        end
                        whisRefX = linspace(fm{i}(end,1), fm{i}(1,1), numPt);
                        fitObj = fit(fm{i}(:,1), fm{i}(:,2), 'poly2');
                        whisRefY = fitObj(whisRefX);
                        
                        % Linear distance approximation (underestimating)
                        refIdx = wid{i} + 2;
                        fPos(i,:) = [ whisRefX(refIdx) whisRefY(refIdx) ];
                        vects(i,:) = pPos(i,:) - fPos(i,:);
                        dists(i) = norm(vects(i,:));
                    end
                    
                    exclusionInd = find(dists < minDistalRoi + minBarToRoi);
                    midRangeInd = find(dists >= minDistalRoi + minBarToRoi & dists < maxDistalRoi + minBarToRoi);
                    fullLengthInd = find(dists >= maxDistalRoi + minBarToRoi);
                    
                    if isempty(midRangeInd)
                        distalRoi = maxDistalRoi;
                    else
                        distalRoi = min(dists(midRangeInd)) - minBarToRoi;
                    end
                    pixelWhisRoi = round([ proximalRoi, distalRoi ]);
                    r_in_mm = (distalRoi - rToDistalRoi) / pxPerMm;
                    validBarInd = barInd;
                    validBarInd(exclusionInd) = [];
                    
                    fprintf('%d trials will be excluded\n', length(exclusionInd));
                    fprintf('%.2f%% of trials eligible for computing physics\n', length(exclusionInd)/size(pipressWithBar,1)*100);
                    fprintf('%.2f%% of all trials\n', length(exclusionInd)/size(this.pipress,1)*100);
                    
                    
                    % Visualization
                    figure(1)
                    clf(gcf)
                    hold on
                    for i = fullLengthInd
                        plot([ pPos(i,1), fPos(i,1) ], [ pPos(i,2), fPos(i,2) ], ...
                            'Color', [ 0.9 0.9 0.9 ], 'LineWidth', 1);
                    end
                    for i = midRangeInd
                        plot([ pPos(i,1), fPos(i,1) ], [ pPos(i,2), fPos(i,2) ], ...
                            'Color', [ 1 0.7 0.7 ], 'LineWidth', 1);
                    end
                    for i = exclusionInd
                        plot([ pPos(i,1), fPos(i,1) ], [ pPos(i,2), fPos(i,2) ], ...
                            'Color', [ 0.8 0 0 ], 'LineWidth', 1);
                        text(fPos(i,1), fPos(i,2), num2str(barInd(i)), 'Color', [ 0.8 0 0 ]);
                    end
                    for i = [ fullLengthInd, midRangeInd ]
                        percentRange = pixelWhisRoi/dists(i);
                        x = percentRange * vects(i,1) + fPos(i,1);
                        y = percentRange * vects(i,2) + fPos(i,2);
                        plot(x, y, 'Color', [ 0.5 0.5 1 ], 'LineWidth', 1);
                    end
                    plot(pPos(:,1), pPos(:,2), 'xb');
                    hold off, axis ij equal, xlim([ 1 640 ]), ylim([ 1 480 ]);
                    
                    
                    figure(2)
                    clf(gcf)
                    hold on
                    for i = fullLengthInd
                        plot([ 0 vects(i,1) ], [ 0 vects(i,2) ], ...
                            'Color', [ 0.9 0.9 0.9 ], 'LineWidth', 1);
                    end
                    for i = midRangeInd
                        plot([ 0 vects(i,1) ], [ 0 vects(i,2) ], ...
                            'Color', [ 1 0.7 0.7 ], 'LineWidth', 1);
                    end
                    for i = exclusionInd
                        plot([ 0 vects(i,1) ], [ 0 vects(i,2) ], ...
                            'Color', [ 0.8 0 0 ], 'LineWidth', 1);
                    end
                    for i = [ fullLengthInd, midRangeInd ]
                        percentRange = [ pixelWhisRoi r_in_mm*pxPerMm ] / dists(i);
                        x = percentRange * vects(i,1);
                        y = percentRange * vects(i,2);
                        plot(x(1:2), y(1:2), 'Color', [ 0.5 0.5 1 ], 'LineWidth', 1);
                        plot(x(3), y(3), 'k.', 'MarkerSize', 4);
                    end
                    plot(vects(:,1), vects(:,2), 'xb');
                    hold off, axis ij equal;
                    
                    
                    figure(3)
                    set(gcf, 'Name', 'Distribution of pole distance');
                    hist(dists);
                    
                else
                    % Use optimal parameters if no trial has bar info
                    pixelWhisRoi = round([proximalRoi, maxDistalRoi]);
                    r_in_mm = (maxDistalRoi - rToDistalRoi) / pxPerMm;
                    disp('No trial has bar information. Optimal parameters will be used.');
                end
                
                fprintf('The length of whisker ROI is %.2fmm (from %.2fmm to %.2fmm, [%d %d])\n', ...
                    diff(pixelWhisRoi)/pxPerMm, pixelWhisRoi(1)/pxPerMm, pixelWhisRoi(2)/pxPerMm, pixelWhisRoi(1), pixelWhisRoi(2));
                fprintf('The point of measurement is at %.2fmm\n', r_in_mm);
                
                
                % Apply results
                button = questdlg('Do you want to fill the parameters into pipress and save the pipress?', ...
                    'Message', 'Yes', 'No', 'No');
                
                if strcmp(button, 'Yes')
                    % Combine eligible trials
                    paramMask = noBarMask;
                    if any(barMask)
                        paramMask(validBarInd) = true;
                    end
                    
                    % Clear all parameters
                    this.pipressObj.pipress.whiskerRoi = cellfun(@(x){NaN}, this.pipress.whiskerRoi);
                    this.pipressObj.pipress.r = cellfun(@(x){NaN}, this.pipress.r);
                    
                    % Set new parameters
                    this.pipressObj.pipress.whiskerRoi(paramMask) = repmat({pixelWhisRoi}, [sum(paramMask), 1]);
                    this.pipressObj.pipress.r(paramMask) = repmat({r_in_mm}, [sum(paramMask), 1]);
                    
                    % Save pipress
                    this.SavePipress();
                    msgbox('Parameters are filled and the pipress is saved!', 'Saved');
                end
            end
        end
        
        % Generating cfit object for correcting raw kappa measurement
        function [ kappa_param, medianKappa ] = GetBaselineKappaFit(this, varargin)
            % Generating cfit object for correcting raw kappa measurement
            
            % Handles user inputs
            p = inputParser();
            p.addParameter('plot', true, @islogical);
            p.parse(varargin{:});
            toPlot = p.Results.plot;
            
            
            % Pools available WhiskerTrialLite objects
            physMask = cellfun(@(x) StringTool.MatchRegExps(x, {'^computed', '^curated'}), this.pipress.physics);
            physPaths = cellfun(@(x,y) fullfile(x,[y '_WL.mat']), this.pipress.dir, this.pipress.trialName, 'Uni', false);
            wls = cellfun(@(x) load(x, 'wl'), physPaths(physMask), 'Uni', false);
            
            
            % Get kappa (smooth to reduce hitch around theta = 0 (pixelation-fit issue))
            kappa = cellfun(@(x) x.wl.get_deltaKappa(x.wl.trajectoryIDs(1))', wls, 'Uni', false);
            kappaVect = cell2mat(kappa);
            
            % Get smoothed kinematics
            theta = cellfun(@(x) x.wl.get_thetaAtBase(x.wl.trajectoryIDs(1))', wls, 'Uni', false);
            theta = cellfun(@(x) smooth(x, 9, 'sgolay', 3), theta, 'Uni', false);
            vel = cellfun(@(x) smooth(DGradient(x)/2, 9, 'sgolay', 3), theta, 'Uni', false);
            acc = cellfun(@(x) smooth(DGradient(x)/2, 9, 'sgolay', 3), vel, 'Uni', false);
            thetaVect = cell2mat(theta);
            accVect = cell2mat(acc);
            
            
            % Masking
            [~, indKeptKappa] = MMath.RemoveOutliers(kappaVect, 0.5, 'percentile');
            [~, indKeptTheta] = MMath.RemoveOutliers(thetaVect, 0.25, 'percentile');
            [~, indKeptAcc] = MMath.RemoveOutliers(accVect, 0.25, 'percentile');
            
            amp = cellfun(@(x) x.wl.get_amplitude(x.wl.trajectoryIDs(1))', wls, 'Uni', false);
            ampVect = cell2mat(amp);
            
            noPoleMask = cellfun(@(x) isempty(x.wl.get_distanceToPoleCenter(x.wl.trajectoryIDs(1))'), wls);
            d2p = cellfun(@(x) x.wl.get_distanceToPoleCenter(x.wl.trajectoryIDs(1))', wls, 'Uni', false);
            d2p(noPoleMask) = cellfun(@(x) zeros(size(x)), amp(noPoleMask), 'Uni', false);
            d2pVect = cell2mat(d2p);
            
            accCutoff = 0.03;
            
            maskWia = d2pVect>1 & ampVect>2.5 & indKeptKappa & indKeptTheta & indKeptAcc;
            maskWiaLowAcc = d2pVect>1 & ampVect>2.5 & abs(accVect)<accCutoff & indKeptKappa & indKeptTheta & indKeptAcc;
            
            
            % Tuning
            tuning = MNeural.Tuning(thetaVect, kappaVect, 'mask', maskWiaLowAcc);
            tuning = tuning{1};
            
            
            % Fitting (kappa_param is a cfit object)
            kappa_param_Old = fit(thetaVect(maskWia), kappaVect(maskWia), 'poly2');
            kappa_param = fit(tuning(:,1), tuning(:,2), 'poly2');
            
            cfitCorrectedKappa = cellfun(@(k,t) k - kappa_param(t), kappa, theta, 'Uni', false);
            cfitCorrectedKappaVect = cell2mat(cfitCorrectedKappa);
            
            medianKappa = cellfun(@(k,d,a) nanmedian(k(d>1)), cfitCorrectedKappa, d2p, acc);
%             medianKappa = cellfun(@(k,d,a) nanmedian(k(d>1 & a<accCutoff)), cKappa, d2p, acc);
            
            minNumSample = 50;
            sampleNumMask = cellfun(@(k,d,a) sum(~isnan(k(d>1))) < minNumSample, kappa, d2p, acc);
%             sampleNumMask = cellfun(@(d,a) sum(~isnan(k(d>1)) & a<accCutoff) < minNumSample, d2p, acc);
            medianKappa(sampleNumMask) = 0;
            
            medianCorrectedKappa = cellfun(@(k,m) k - m, cfitCorrectedKappa, num2cell(medianKappa), 'Uni', false);
            medianCorrectedKappaVect = cell2mat(medianCorrectedKappa);
            
            % Additional info
            [jointDist, binCenters] = MMath.JointDist([kappaVect(maskWia), thetaVect(maskWia)], 30);
            jointDist = jointDist * sum(maskWia);
            
            [jointDist2, binCenters2] = MMath.JointDist([kappaVect(maskWiaLowAcc), thetaVect(maskWiaLowAcc)], 30);
            jointDist2 = jointDist2 * sum(maskWiaLowAcc);
            
            
            % Plotting
            if toPlot
                figure(8239); clf
                set(gcf,'Color','w');
                
                numPoints = 3000;
                indWia = find(maskWia);
                indWia = randsample(indWia, min(numPoints, length(indWia)));
                indWiaLowAcc = find(maskWiaLowAcc);
                indWiaLowAcc = randsample(indWiaLowAcc, min(numPoints, length(indWiaLowAcc)));
                
                
                % Scatter plot and fits
                subplot(2,3,1); cla
                plot(thetaVect(indWia), kappaVect(indWia), 'd', 'Color', 'b', 'MarkerSize', 1); hold on
                plot(thetaVect(indWiaLowAcc), kappaVect(indWiaLowAcc), 'd', 'Color', 'r', 'MarkerSize', 1);
                axis tight
                plot(tuning(:,1), tuning(:,2), 'm', 'LineWidth', 3);
                plot(kappa_param_Old, 'g');
                plot(kappa_param, 'm');
                
                title('Kappa (raw) variance given theta', 'FontSize', 16);
                ylabel('Kappa (raw)','FontSize',14);
                xlabel('\theta (degree)', 'FontSize', 16);
                
                % Full sample distributions
                subplot(2,3,2); cla
                MPlot.Pcolor(binCenters{2}, binCenters{1}, jointDist);
                shading interp
                caxis([0 max(jointDist(:))]);
                title('WIA full sample distribution', 'FontSize', 16);
                
                % Low acc sample distributions
                subplot(2,3,3); cla
                MPlot.Pcolor(binCenters2{2}, binCenters2{1}, jointDist2);
                shading interp
                caxis([0 max(jointDist(:))]);
                title('WIA low acceleration sample distribution', 'FontSize', 16);
                
                % Sample distributions by acc
                subplot(2,3,4); cla
                numBins = 150;
                [vals, centers] = hist(accVect(maskWia), numBins);
                bar(centers, vals, 'b', 'EdgeColor', 'none'); hold on
                vals = hist(accVect(maskWiaLowAcc), centers);
                bar(centers, vals, 'r', 'EdgeColor', 'none');
                title('acceleration', 'FontSize', 16);
                axis tight
                
                % Scatter plot after cfit correction
                subplot(2,3,5); cla
                plot(thetaVect(indWia), kappaVect(indWia), 'd', 'Color', 'b', 'MarkerSize', 1); hold on
                plot(thetaVect(indWia), cfitCorrectedKappaVect(indWia), 'd', 'Color', 'r', 'MarkerSize', 1);
                axis tight
                
                title('cfit corrected kappa over theta', 'FontSize', 14);
                ylabel('Kappa (raw)', 'FontSize', 14);
                xlabel('\theta (degree)', 'FontSize', 14);
                
                % Scatter plot after median correction
                subplot(2,3,6); cla
                plot(thetaVect(indWia), kappaVect(indWia), 'd', 'Color', 'b', 'MarkerSize', 1); hold on
                plot(thetaVect(indWia), medianCorrectedKappaVect(indWia), 'd', 'Color', 'r', 'MarkerSize', 1);
                axis tight
                
                title('cfit and median corrected kappa over theta', 'FontSize', 14);
                ylabel('cfit and median corrected kappa', 'FontSize', 14);
                xlabel('\theta (degree)', 'FontSize', 14);
                
                
                savefig(fullfile(this.mainFolder, 'kappa correction'));
            end
            
            
            % Save results
            save(fullfile(this.mainFolder, 'kappa_param'), 'kappa_param', 'medianKappa');
            this.kappaParam = kappa_param;
        end
        
        % Eliminates unqualified physics
        function paths2del = CleanPhysicsFiles(this)
            % Finds the indices of unqualified trials
            ind2del = cellfun(@(x) ~StringTool.MatchRegExps(x, {'^computed', '^curated', '^skip'}), this.pipress.contacts);
            
            % Gets the paths of unqualified _WL.mat files
            paths2del = cellfun(@(x,y) fullfile(x, [y '_WL.mat']), ...
                this.pipress.dir(ind2del), this.pipress.trialName(ind2del), 'UniformOutput', false);
            
            % Finds which need to be deleted
            indExist = logical(cellfun(@(x) exist(x, 'file'), paths2del));
            paths2del = paths2del(indExist);
            
            % Deletion
            if isempty(paths2del)
                msgbox('No need to clean physics files');
            else
                dlgAns = listdlg('ListString', paths2del, ...
                    'SelectionMode', 'multiple', ...
                    'Name', 'Select files to delete', ...
                    'ListSize', [ 700 300 ]);
                cellfun(@(x) delete(x), paths2del(dlgAns));
            end
        end
        
    end
    
    methods(Access = private)
        function SetupPipress(this, sessionDictPath, sessionDictEntryIdx)
            % Load pipress if exist, otherwise creates anew
            if exist([ this.pipressPath, '.mat' ], 'file') && exist([ this.pipressPath, '.xls' ], 'file')
                % Load pipress (without updating from session_dictionary.xlsx)
                this.LoadPipress(sessionDictPath, sessionDictEntryIdx);
                this.firstRun = false;
                
                % Updates file directory in case of any change
                this.pipressObj.pipress.dir = repmat({ fullfile(this.mainFolder, 'workspace') }, length(this.pipressObj.pipress.dir), 1);
            else
                this.CreatePipress(sessionDictPath, sessionDictEntryIdx);
            end
            
            % Creates bars gallery folder if not exist
            if ~exist(this.barGalleryFolder, 'dir')
                mkdir(this.barGalleryFolder);
            end
        end
        
    end
    
end

