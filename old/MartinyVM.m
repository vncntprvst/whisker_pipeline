classdef MartinyVM < handle
    %MARTINYVM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        tifNowObj;
        whiskers;
        measurements;
        facemasks;
        whiskerSignalTrialObj;
        whiskerTrialLiteObj;
        
        currentFrame = 0;
        showRawTrajectory = false;
        showFittedTrajectory = false;
        showFacemask = false;
        
        handleImage;
        handleTrajectory;
        handleFacemask;
        handleProfile;
        
        contactTemp = [ NaN NaN ];
        contactChanged = false;
    end
    
    properties(Dependent)
        tifName;
        hasImage;
        hasFittedTrajectory;
        hasRawTrajectory;
        hasFacemask;
    end
    
    methods
        function val = get.tifName(this)
            if this.hasImage
                [ ~, val ] = fileparts(this.tifNowObj.filePath);
            else
                val = 'Martiny';
            end
        end
        function val = get.hasImage(this)
            [ ~, ~, ext ] = fileparts(this.tifNowObj.filePath);
            if strcmp(ext, '.mp4')
                val = isa(this.tifNowObj.img, 'uint8');
            elseif strcmp(ext, '.tif')
                val = isa(this.tifNowObj, 'TiffNow');
            end
        end
        function val = get.hasFacemask(this)
            val = ~isempty(this.facemasks);
        end
        function val = get.hasFittedTrajectory(this)
            val = ~isempty(this.whiskerSignalTrialObj);
        end
        function val = get.hasRawTrajectory(this)
            val = ~isempty(this.whiskers) && ~isempty(this.measurements);
        end
    end
    
    methods
        function this = MartinyVM(varargin)
            p = inputParser();
            p.addParameter('tifPath', []);
            p.addParameter('loadRawTrajectory', true);
            p.addParameter('loadPhysics', true);
            p.addParameter('loadFacemask', true);
            
            p.parse(varargin{:});
            if isempty(p.Results.tifPath)
                tifPath = Browse.File();
            else
                tifPath = p.Results.tifPath;
            end
            loadRawTrajectory = p.Results.loadRawTrajectory;
            loadPhysics = p.Results.loadPhysics;
            loadFacemask = p.Results.loadFacemask;
            
            if exist(tifPath, 'file')
                % Load four components
                try
                    tic;
                    [~,~,ext] = fileparts(tifPath);
                    if strcmp(ext,'.mp4')
                        this.tifNowObj.img = Img23.ImportMP4(tifPath);
                        this.tifNowObj.filePath = tifPath;
                    elseif strcmp(ext,'.tif')
                        this.tifNowObj = TiffNow(tifPath, 'loadingInterval', 0.15);
                    end
                    fprintf('Loading video... ');
                    toc;
                    
                    if loadRawTrajectory
                        this.LoadWhiskersAndMeasurements(tifPath);
                    end
                    this.showRawTrajectory = this.hasRawTrajectory;
                    
                    if loadPhysics
                        this.LoadPhysics(tifPath);
                    end
                    this.showFittedTrajectory = this.hasFittedTrajectory;
                    
                    if loadFacemask
                        this.LoadFacemasks(tifPath);
                    end
                    this.showFacemask = this.hasFacemask;
                    
                catch e
                    e
                end
            end
        end
        function LoadWhiskersAndMeasurements(this, tifPath)
            try
                [ pathstr, name ] = fileparts(tifPath);

                % Loads .measurements file and converts the struct to table for later convenience
                measurementsPath = fullfile(pathstr, [ name, '.measurements' ]);
                if exist(measurementsPath, 'file')
                    tic;
                    this.measurements = struct2table(Whisker.LoadMeasurements(measurementsPath));
                    fprintf('.measurements file loaded: ');
                    toc;
                else
                    disp('.measurements file not found');
                end
                
                % Loads .whiskers file and converts the nested cell array to table for later convenience
                whiskersPath = fullfile(pathstr, [ name, '.whiskers' ]);
                if exist(whiskersPath, 'file')
                    tic;
                    try
                        this.whiskers = struct2table(Whisker.LoadWhiskers(whiskersPath));
                    catch
                        cellWhiskers = Whisker.load_whiskers_file(whiskersPath);
                        cellWhiskers = [ cellWhiskers{:} ];
                        cellWhiskers = reshape(cellWhiskers, 6, length(cellWhiskers)/6)';
                        cellWhiskers(:,1) = cellfun(@(x,y) repmat(x, length(y), 1), ...
                            cellWhiskers(:,1), cellWhiskers(:,2), 'UniformOutput', false);
                        
                        this.whiskers = table();
                        for i = 1 : 4
                            this.whiskers.(i) = cat(1,cellWhiskers{:,i});
                        end
                        this.whiskers.Properties.VariableNames = { 'fr', 'id', 'x', 'y' };
                    end
                    fprintf('.whiskers file loaded: ');
                    toc;
                else
                    disp('.whiskers file not found');
                end
            catch
                e
            end
        end
        function LoadPhysics(this, tifPath)
            try
                [ pathstr, name ] = fileparts(tifPath);
                wlPath = fullfile(pathstr, [ name, '_WL.mat' ]);
                if exist(wlPath, 'file')
                    % Time and load _WL.mat file
                    tic;
                    load(wlPath);
                    fprintf('_WL.mat file loaded: ');
                    toc;
                    
                    % Check the existence WhiskerSignalTrial object
                    if exist('wst', 'var');
                        this.whiskerSignalTrialObj = wst;
                        disp('has WhiskerSignalTrial object');
                    else
                        disp('no WhiskerSignalTrial object');
                    end
                    
                    % Check the existence WhiskerTrialLite object
                    if exist('wl', 'var');
                        this.whiskerTrialLiteObj = wl;
                        disp('has WhiskerTrialLite object');
                    else
                        disp('no WhiskerTrialLite object');
                    end
                else
                    disp('_WL.mat file not found');
                end
            catch
                e
            end
        end
        function LoadFacemasks(this, tifPath)
            try
                [ pathstr, name ] = fileparts(tifPath);
                facemasksPath = fullfile(pathstr, [ name, '.facemasks' ]);
                if exist(facemasksPath, 'file')
                    tic;
                    load(facemasksPath, '-mat');
                    this.facemasks = Masquerade_sideView.Filter(data_faceMasks);
                    fprintf('.facemasks file loaded: ');
                    toc;
                else
                    disp('.facemasks file not found');
                end
            catch
                e
            end
        end
        function SaveContactCuration(this)
            if this.contactChanged
                % Gets the path of contact file
                [ folderPath, fileName ] = fileparts(this.tifNowObj.filePath);
                contactPath = fullfile(folderPath, [ fileName '.contact' ]);
                
                if ~exist(contactPath, 'file')
                    % Creates new file
                    ContactTrainer.SaveContactFile(contactPath, this.whiskerTrialLiteObj.contactManual{1}, ...
                        'trajectory', this.whiskerTrialLiteObj.trajectoryIDs(1));
                else
                    % Updates existing file with new info
                    ContactTrainer.UpdateContactFileLabels(contactPath, ...
                        this.whiskerTrialLiteObj.contactManual{1}, ...
                        this.whiskerTrialLiteObj.trajectoryIDs(1));
                    
                    % Asks user to verify matadata
                    ContactTrainer.UpdateContactFileInfo(contactPath, 'forcedPrompt', true);
                end
                
                if strcmp(questdlg('Do you also want to save contact info to _WL.mat file (WhiskerTrialLite object)?', 'Save', ...
                        'Yes', 'No', 'No'), 'Yes')
                    wl = this.whiskerTrialLiteObj;
                    wst = this.whiskerSignalTrialObj;
                    save(fullfile(folderPath, [ fileName '_WL.mat' ]), 'wl', 'wst');
                end
                
                this.contactChanged = false;
            end
        end
        
        
        % Setters
        function isChanged = SetCurrentFrame(this, frIdx)
            targetFrame = MMath.Bound(frIdx, [ 0, 2499 ]);
            isChanged = targetFrame ~= this.currentFrame;
            this.currentFrame = targetFrame;
        end
        function SetContact(this)
            if ishandle(888)
                % Make sure contactManual is not empty
                if isempty(this.whiskerTrialLiteObj.contactManual)
                    this.whiskerTrialLiteObj.contactManual{1} = zeros(1,2500);
                end
                
                firstNanIdx = find(isnan(this.contactTemp), 1);
                if firstNanIdx
                    % Fill in the range
                    this.contactTemp(firstNanIdx) = this.currentFrame+1;
                else
                    % Gets range and valence
                    this.contactTemp = sort(this.contactTemp);
                    range = this.contactTemp(1) : this.contactTemp(2);
                    valence = ~this.whiskerTrialLiteObj.contactManual{1}(this.currentFrame+1);
                    
                    % Applys to manual contacts
                    this.whiskerTrialLiteObj.contactManual{1}(range) = valence;
                    this.contactChanged = true;
                    % Updates true labels plot
                    set(this.handleProfile.trueLabel, 'YData', this.whiskerTrialLiteObj.contactManual{1});
                    
                    % Applys to auto contacts if applicable
                    if ~isempty(this.whiskerTrialLiteObj.contactAuto)
                        this.whiskerTrialLiteObj.contactAuto{1}(range) = valence;
                        % Updates error labels plot
                        cmpStruct = this.whiskerTrialLiteObj.compare_contacts();
                        indErrLabel = find(cmpStruct.errLabel) - 1;
                        set(this.handleProfile.errLabel, 'XData', indErrLabel, 'YData', ones(size(indErrLabel)));
                    end
                    
                    this.ClearContact();
                end
                    
                % Update plot
                this.ShowContactCuration();
            else
                disp('Profile window is not opened thus contact curation is not available.');
            end
        end
        function ClearContact(this)
            this.contactTemp = nan(1,2);
            this.ShowContactCuration();
        end
        
        
        % To UI
        function ShowFrame(this, hAxes)
            if ishandle(this.handleImage)
                try
                    set(this.handleImage, 'CData', this.GetFrame());
                catch
                end
            else
                if nargin > 1
                    axes(hAxes);
                    hold on;
                end
                this.handleImage = imshow(this.GetFrame());
                colormap gray
                axis equal off
                hold off;
            end
        end
        function ShowTrajectory(this, hAxes)
            % Delete previous plots
            for i = 1 : length(this.handleTrajectory)
                if ishandle(this.handleTrajectory(i))
                    try
                        delete(this.handleTrajectory(i));
                    catch
                    end
                end
            end
            this.handleTrajectory = [];
            
            % Check availability of trajectory info and user options
            plotRaw = this.hasRawTrajectory && this.showRawTrajectory;
            plotFitted = this.hasFittedTrajectory && this.showFittedTrajectory;
            
            % Ploting
            if plotRaw || plotFitted
                % Set focus
                axes(hAxes);
                hold on;
                
                % Get color codes
                numColors = 6;
                colorCode = [ MPlot.ColorCodeRainbow(numColors); ones(30,3) ];
                
                % Get x, y data of each trajectory
                if plotRaw
                    [ trajectories, whiskerLabels ] = this.GetRawTrajectory();
                else
                    [ trajectories, whiskerLabels ] = this.GetFittedTrajectory();
                end
                
                % Plot
                for i = length(whiskerLabels) : -1 : 1
                    if whiskerLabels(i) ~= -1
                        c = colorCode(whiskerLabels(i)+1,:);
                    else
                        c = [ 1 1 1 ];
                    end
                    this.handleTrajectory(i) = plot(trajectories{i}(:,1), trajectories{i}(:,2), 'Color', c);
                end
            end
        end
        function ShowFacemask(this, hAxes)
            if this.hasFacemask && this.showFacemask
                x = MMath.Bound(this.facemasks(this.currentFrame+1,:,1), [ 1 640 ]) + 0.5;
                y = MMath.Bound(this.facemasks(this.currentFrame+1,:,2), [ 1 480 ]) + 0.5;
                if ishandle(this.handleFacemask)
                    set(this.handleFacemask, 'XData', x);
                    set(this.handleFacemask, 'YData', y);
                else
                    if nargin > 1
                        axes(hAxes);
                        hold on;
                    end
                    this.handleFacemask = plot(x, y, 'r', 'LineWidth', 2);
                    hold off;
                end
            else
                if ishandle(this.handleFacemask)
                    delete(this.handleFacemask);
                end
            end
        end
        function ShowProfile(this)
            if isa(this.whiskerTrialLiteObj, 'Whisker.WhiskerTrialLite')
                figure(888);
                set(gcf, 'Color', 'w');
                
                % Plot profile
                this.handleProfile = this.whiskerTrialLiteObj.plot_contact_profile();
                
                % Plot current frame label
                hold on
                this.handleProfile.currentFrameLabel = stem(this.currentFrame, 0.5, 'b.', 'MarkerSize', 16, 'LineWidth', 2);
                
                % Plot contact curation
                if isempty(this.handleProfile.trueLabel)
                    this.handleProfile.trueLabel = stem(0:2499, NaN(1,2500), '.', 'Color', [.8 .8 .8], 'LineWidth', 1.5, 'MarkerSize', 16);
                end
                this.ClearContact();
                this.handleProfile.contactCurationLabel = stem(this.contactTemp, [.5 .5], 'g.', 'MarkerSize', 16, 'LineWidth', 2);
                hold off
            end
        end
        function ShowCurrentFrameLabel(this)
            if isfield(this.handleProfile, 'currentFrameLabel') && ishandle(this.handleProfile.currentFrameLabel)
                % Updates label
                set(this.handleProfile.currentFrameLabel, 'XData', this.currentFrame);
                
                % Updates focus
                hc = get(888, 'Children');
                xWingLength = diff(get(hc(end), 'XLim')) / 2;
                if xWingLength < 100
                    set(hc(end), 'XLim', [ this.currentFrame - xWingLength, this.currentFrame + xWingLength ]);
                end
            end
        end
        function ShowContactCuration(this)
            try
                set(this.handleProfile.contactCurationLabel, 'XData', this.contactTemp-1);
            catch
            end
        end       
        function SaveFigure(this, h)
            try
                session = this.whiskerTrialLiteObj.sessionName;
                trial = num2str(this.whiskerTrialLiteObj.trialNum);
                frame = num2str(this.currentFrame);
                fileName = [ session '_Num' trial '_Frame' frame ];
            catch
                fileName = 'img';
            end
            imwrite(frame2im(getframe(h)), [ fileName '.tif' ]);
        end
        
        
        % Destructor
        function delete(this)
            % Check changes of contact info
            if this.contactChanged
                dlgAns = questdlg('Contact information was changed. Do you want to save it?', 'Contact changed', 'Yes', 'No', 'No');
                if strcmp(dlgAns, 'Yes')
                    this.SaveContactCuration();
                end
            end
            
            % Clear up objects
            if isa(this.tifNowObj.img, 'uint8')
                delete(this.tifNowObj);
            end
            if ishandle(this.handleImage)
                delete(this.handleImage);
            end
            if ishandle(this.handleTrajectory)
                delete(this.handleTrajectory);
            end
            if ishandle(this.handleFacemask)
                delete(this.handleFacemask);
            end
            if ishandle(888)
                delete(888);
            end
            pause(0.5);
        end
    end
    
    methods(Access = private)
        % Private getters
        function img = GetFrame(this, frIdx)
            if nargin < 2
                frIdx = this.currentFrame;
            end
            img = this.tifNowObj.img(':',':',frIdx+1);
        end
        function [ trajectories, whiskerLabels ] = GetRawTrajectory(this, frIdx)
            if nargin < 2
                frIdx = this.currentFrame;
            end
            
            frMask = this.measurements.fid == frIdx;
            whiskMask = this.measurements.length > 110;
            finalInd = find(frMask & whiskMask);
            
            try
                frWhiskers = this.whiskers(this.whiskers.fr == frIdx, 1:4);
            catch
                frWhiskers = this.whiskers(this.whiskers.time == frIdx, 1:4);
            end
            whiskerLabels = this.measurements.label(finalInd);
            trajectories = cell(length(whiskerLabels), 1);
            
            for i = 1 : length(finalInd)
                wid = this.measurements.wid(finalInd(i));
                whiskEntryIdx = find(frWhiskers.id == wid, 1);
                trajectories{i} = [ frWhiskers.x{whiskEntryIdx} + .5, frWhiskers.y{whiskEntryIdx} + .5 ];
            end
        end
        function [ trajectory, whiskerLabel ] = GetFittedTrajectory(this, frIdx)
            if nargin < 2
                frIdx = this.currentFrame;
            end
            
            timeSeries = this.whiskerSignalTrialObj.get_time(this.whiskerSignalTrialObj.trajectoryIDs(1));
            frSeries = round(timeSeries * 500);
            dataIdx = find(frSeries == frIdx);
            
            if ~isempty(dataIdx)
                px = this.whiskerSignalTrialObj.polyFits{1}{1}(dataIdx,:);
                py = this.whiskerSignalTrialObj.polyFits{1}{2}(dataIdx,:);

                q = linspace(0,1);
                trajectory{1} = [ polyval(px,q) + .5; polyval(py,q) + .5 ]';
                whiskerLabel = this.whiskerSignalTrialObj.trajectoryIDs(1);
            else
                trajectory = {};
                whiskerLabel = [];
            end
        end
    end
    
end

