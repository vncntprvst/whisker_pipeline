classdef OneWhisker < handle
    %MANYWHISKERS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Progress and performance
        silent;             % handle all problems and reports silently if set to ture
        checkTable;         % where progress and performance are logged
        rowNames = { 'file'; 'measurements'; 'bar'; 'facemasks'; 'physics'; 'contacts' };
        columnNames = { 'status', 'report' };
        
        % Data and metadata
        folderPath;         % path of the folder containing all files of this trial
        commonName;         % common trial name of files
        infoStruct;         % stores metadata about this trial (e.g. whiskerID)
        dataStruct;         % stores data used during processing (e.g. measurement struct, tif array, etc)
        objStruct;          % object version of dataStruct members
    end
    
    methods
        function this = OneWhisker(varargin)
            % Constructor of OneWhisker class
            
            % Parse user inputs
            p = inputParser;
            p.addParameter('path', [], @ischar);            % path of any file containing the common trial name
            p.addParameter('silent', false, @islogical);    % handle all problems silently if set to ture
            p.addParameter('whiskerID', @isnumeric);
            
            p.addParameter('distToFace', 10, @isnumeric);
            
            p.addParameter('polyRoiInPix', NaN, @isnumeric);
            p.addParameter('rInMm', NaN, @isnumeric);
            p.addParameter('baselineKappaParam', 0);
            
            p.addParameter('whiskerLengthInMm', NaN, @isnumeric);
            p.addParameter('whiskerRadiusAtBaseInMicron', NaN, @isnumeric);
            
            p.addParameter('faceSideInImage', 'bottom', @ischar);
            p.addParameter('protractionDirection', 'leftward', @ischar);
            
            p.parse(varargin{:});
            filePath = p.Results.path;
            this.silent = p.Results.silent;
            this.infoStruct = p.Results;
            this.infoStruct = rmfield(this.infoStruct, { 'path', 'silent' });
            
            % Prompt file selection UI when applicable
            if ~exist(filePath, 'file') && ~this.silent
                filePath = Browse.File();
            end
            
            % Initialize the check list
            this.checkTable = table(repmat({ 'none' }, size(this.rowNames)), ...
                cell(size(this.rowNames)), ...
                'RowNames', this.rowNames, 'VariableNames', this.columnNames);
            
            % Check the existence of the file
            if exist(filePath, 'file')
                this.checkTable{'file','status'} = {'found'};
            else
                this.checkTable{'file','status'} = {'error: file not found'};
            end
            this.checkTable{'file','report'} = {filePath};
            
            % Required info for processing in the absence of target file (such as the TIFF)
            try
                [ this.folderPath, this.commonName ] = fileparts(filePath);
            catch
            end
        end
        
        % Whisker linking (registration)
        function LinkWhiskers(this, varargin)
            % Whisker linking (registration)
            
            % Handle user inputs
            p = inputParser();
            p.addParameter('Force', true, @islogical);
            p.parse(varargin{:});
            force = p.Results.Force;
            
            % Check if the file path is valid
            if strcmp(this.checkTable{'file','status'}, 'found')
                
                measurementsPath = fullfile(this.folderPath, [ this.commonName '.measurements' ]);
%                 maskPath = fullfile(this.folderPath, [ this.commonName, '.facemasks' ]);
                
                if exist(measurementsPath, 'file') && ~force
                    % If the .measurements file already exists and the computation is not forced
                    this.checkTable{'measurements','status'} = {'found'};
                    this.checkTable{'measurements','report'} = {measurementsPath};
%                     load(maskPath, '-mat');
%                     this.dataStruct.facemasks = data_faceMasks;
                    
                else
                    % Whisker linking
                    try
                        % Load .measurements file if has not been loaded
                        if ~isfield(this.dataStruct, 'measurements')
                            this.dataStruct.measurements = Whisker.LoadMeasurements(measurementsPath);
%                             load(maskPath, '-mat');
%                             this.dataStruct.facemasks = data_faceMasks;
                        end
                        
                        % Linking
                        this.objStruct.measurements = WhiskerLinkerLite(this.dataStruct.measurements);
%                         this.objStruct.measurements = WhiskerLinkerLite2(this.dataStruct.measurements, this.dataStruct.facemasks);
                        
                        % Decise whether to save the linking result
                        isAbsent = ~any(this.objStruct.measurements.detectedWhiskerIDs == this.infoStruct.whiskerID);
                        decision = 'Yes';
                        if ~this.silent
                            this.objStruct.measurements.PlotReport();
                            if isAbsent || ~isempty(this.objStruct.measurements.missingTable)
                                decision = questdlg(sprintf([ 'Please check the registration report for more information.\n' ...
                                    'Do you want to save this registration result and replace the existing one?\n' ]), ...
                                    'Missing detection');
                            end
                        else
                            missingFrames = find(this.objStruct.measurements.missingTable.WhiskerID == this.infoStruct.whiskerID);
                            if isAbsent || length(missingFrames) > 25
                                decision = 'No';
                            end
                        end

                        % Save result
                        if strcmp(decision, 'Yes')
                            this.objStruct.measurements.Save(measurementsPath);
                            this.dataStruct.measurements = this.objStruct.measurements.outMeasurements;
                            this.checkTable{'measurements','status'} = {'computed'};
                        else
                            if this.silent % always save result in silent mode
                                this.objStruct.measurements.Save(measurementsPath);
                            end
                            this.checkTable{'measurements','status'} = {'error: failed quality control'};
                        end
                        this.checkTable{'measurements','report'} = { this.objStruct.measurements.missingTable };
                        
                    catch e
                        this.checkTable{'measurements','status'} = {'error: loading, linking or saving failed'};
                        this.checkTable{'measurements','report'} = {e};
                    end
                end
            end
        end
        
        % Bar center detection
        function DetectBar(this, varargin)
            % Bar center detection
            
            % Handle user inputs
            p = inputParser();
            p.addParameter('Arm', [], @isnumeric);
            p.addParameter('Pole', [], @isnumeric);
            p.addParameter('Force', true, @islogical);
            p.addParameter('PosImgDir', '', @ischar);
            p.parse(varargin{:});
            arm = p.Results.Arm;
            pole = p.Results.Pole;
            force = p.Results.Force;
            posImgDir = p.Results.PosImgDir;
            
            % Check if the file path is valid
            if strcmp(this.checkTable{'file','status'}, 'found') 
                
                barPath = fullfile(this.folderPath, [ this.commonName '.bar' ]);
                
                if exist(barPath, 'file') && ~force
                    % If the .bar file already exists and the computation is not forced
                    this.checkTable{'bar','status'} = {'found'};
                    this.checkTable{'bar','report'} = {barPath};
                    
                else
                    % Find the bar position
                    try
                        % Load the first and last frames if have not been loaded by facemasks
                        if isfield(this.dataStruct, 'tif')
                            frame0 = this.dataStruct.tif(:,:,1);
                            frame2499 = this.dataStruct.tif(:,:,2500);
                        elseif exist(fullfile(this.folderPath, [this.commonName '.tif']), 'file')==2
                            videoPath = fullfile(this.folderPath, [ this.commonName '.tif' ]);
                            frame0 = Img23.Import(videoPath, 'range', [ 1 1 ]);
                            frame2499 = Img23.Import(videoPath, 'range', [ 2500 2500 ]);
                        elseif exist(fullfile(this.folderPath,[this.commonName '.mp4']), 'file')==2
                            videoPath = fullfile(this.folderPath, [ this.commonName '.mp4' ]);
                            frame0 = Img23.ImportMP4(videoPath, 'range', [ 1 1 ]);
                            frame2499 = Img23.ImportMP4(videoPath, 'range', [ 2500 2500 ]);
                        end
                        
                        % Find pole centers in the first and last frame respectively
                        this.objStruct.bar0 = Bartender('Image', frame0);
                        this.objStruct.bar0.Tend('Arm', arm, 'Pole', pole);
                        this.objStruct.bar2499 = Bartender('Image', frame2499);
                        this.objStruct.bar2499.Tend('Arm', arm, 'Pole', pole);
                        
                        % Save marked pole image(only the 1st frame) if a folder path is provided (not empty)
                        if ~isempty(posImgDir)
                            imgMark = cat(3, zeros(size(frame0), 'like', frame0), frame0, frame2499);
                            try % in case pole position is outside of the frame
                                poleCoor = this.objStruct.bar0.polePos;
                                imgMark(poleCoor(2)-2:poleCoor(2)+2, poleCoor(1)-2:poleCoor(1)+2, 1) = 255;
                            catch
                            end
                            imwrite(imgMark, fullfile(posImgDir, [ this.commonName, '.png' ]));
                        end
                        
                        % Quality control
                        if ~this.silent
                            this.objStruct.bar0.ShowResult();
                            this.objStruct.bar2499.ShowResult();
                        end
                        if this.objStruct.bar0.IsValid()
                            if ~this.objStruct.bar0.IsMoved(this.objStruct.bar2499.polePos)
                                this.objStruct.bar0.SaveBarFile(this.folderPath, this.commonName); % save .bar file
                                this.checkTable{'bar','status'} = {'computed'};
                            else
                                this.checkTable{'bar','status'} = {'error: putative moving bar'};
                            end
                        else
                            this.checkTable{'bar','status'} = {'error: no bar detected'};
                        end
                        s.minMSE = [ this.objStruct.bar0.minMSE; this.objStruct.bar2499.minMSE ];
                        s.coordinate = [ this.objStruct.bar0.polePos; this.objStruct.bar2499.polePos ];
                        this.checkTable{'bar','report'} = {s};
                        
                    catch e
                        % Document error info and save a blank picture
                        this.checkTable{'bar','status'} = {'error: computation failed'};
                        this.checkTable{'bar','report'} = {e};
                        imwrite(zeros(480,640,3,'uint8'), fullfile(posImgDir, [ this.commonName, '.png' ]));
                    end
                end
            end
        end
        
        % Facemasking
        function MakeMasks(this, varargin)
            % Facemasking
            
            % Handle user inputs
            p = inputParser();
            p.addParameter('Force', true, @islogical);
            p.parse(varargin{:});
            force = p.Results.Force;
            
            % Check if the file path is valid
            if strcmp(this.checkTable{'file','status'}, 'found')
                maskPath = fullfile(this.folderPath, [ this.commonName, '.facemasks' ]);
                if exist(maskPath, 'file') && ~force
                    % Load .facemasks file if already exists
                    try
                        load(maskPath, '-mat');
                        this.dataStruct.facemasks = data_faceMasks;
                        this.checkTable{'facemasks','status'} = {'found'};
                        this.checkTable{'facemasks','report'} = {maskPath};
                    catch e
                        this.checkTable{'facemasks','status'} = {'error: loading failed'};
                        this.checkTable{'facemasks','report'} = {e};
                    end
                    
                elseif StringTool.MatchRegExps(this.checkTable{'measurements','status'}{1}, {'^found', '^computed', '^curated'})
                    % Make masks (if linking is valid)
                    try
                        if ~isfield(this.dataStruct, 'tif')
                            if exist(fullfile(this.folderPath,[ this.commonName '.tif' ]), 'file')==2
                                videoPath = fullfile(this.folderPath, [ this.commonName '.tif' ]);
                                this.dataStruct.tif = Img23.Import(videoPath);
                            elseif exist(fullfile(this.folderPath,[ this.commonName '.mp4' ]), 'file')==2
                                videoPath = fullfile(this.folderPath, [ this.commonName '.mp4' ]);
                                this.dataStruct.tif = Img23.ImportMP4(videoPath);
                            end
                        end
                        if ~isfield(this.dataStruct, 'measurements')
                            measurePath = fullfile(this.folderPath, [ this.commonName '.measurements' ]);
                            this.dataStruct.measurements = Whisker.LoadMeasurements(measurePath);
                        end
                        this.objStruct.facemasks = Masquerade(this.dataStruct.tif);
                        this.objStruct.facemasks.Dance(this.dataStruct.measurements, 10, 60, this.infoStruct.distToFace, this.infoStruct.faceSideInImage);
                        
                        % Quality control
                        if ~this.silent
                            this.objStruct.facemasks.ShowResult(1);
                        end
                        
                        % Save .facemasks file
                        fmPath = fullfile(this.folderPath, [ this.commonName '.facemasks' ]);
                        this.objStruct.facemasks.SaveMasks(fmPath);
                        this.dataStruct.facemasks = this.objStruct.facemasks.ptMasks;
                        this.checkTable{'facemasks','status'} = {'computed'};
                        this.checkTable{'facemasks','report'} = {squeeze(this.dataStruct.facemasks(1,:,:))};
                        
                    catch e
                        this.checkTable{'facemasks','status'} = {'error: making masks failed'};
                        this.checkTable{'facemasks','report'} = {e};
                    end
                end
            end
        end
        
        % Computing physics
        function DoPhysics(this, varargin)
            % Computing physics
            
            % Handle inputs
            p = inputParser();
            p.addParameter('Force', true, @islogical);
            
            p.parse(varargin{:});
            force = p.Results.Force;
            
            % Make sure all required files/data are ready
            ready = strcmp(this.checkTable{'file','status'}, 'found') ...
                && any(strcmp(this.checkTable{'measurements','status'}, {'computed','curated','found'})) ...
                && any(strcmp(this.checkTable{'facemasks','status' }, {'computed','curated','found'})) ...
                && any(strcmp(this.checkTable{'bar','status'}, {'computed','curated','curated: error no bar','found'})) ...
                && ~any(structfun(@(x) isnan(x(1)), this.infoStruct));
            
            physPath = fullfile(this.folderPath, [ this.commonName, '_WL.mat' ]);
            
            if exist(physPath, 'file') && ~force
                % Change status directly if the file can be found
                this.checkTable{ 'physics', 'status' } = {'found'};
                this.checkTable{ 'physics', 'report' } = {''};
                
            elseif ready
                % Compute physical quantities
                try
                    % Initialize object
                    filePath = fullfile(this.folderPath, [ this.commonName '.tif' ]);
                    if isfield(this.dataStruct, 'facemasks')
                        this.objStruct.physics = WhisPhys(filePath, this.dataStruct.facemasks);
                    else
                        this.objStruct.physics = WhisPhys(filePath);
                    end
                    
                    % Compute physical quantities
                    if strcmp(this.checkTable{'bar','status'}, 'curated: error no bar')
                        % When the bar is absent
                        this.objStruct.physics.Compute( ...
                            'whiskerID', this.infoStruct.whiskerID, ...
                            'follicleExtrapDistInPix', this.infoStruct.distToFace, ...
                            'polyRoiInPix', this.infoStruct.polyRoiInPix, ...
                            'r_in_mm', this.infoStruct.rInMm, ...
                            'baseline_time_or_kappa_value', this.infoStruct.baselineKappaParam, ...
                            'calc_forces', false, ...
                            'faceSideInImage', this.infoStruct.faceSideInImage, ...
                            'protractionDirection', this.infoStruct.protractionDirection);
                        
                        % Save
%                         if size(this.objStruct.physics.nanTable,1) > 50
                        if sum(table2array(this.objStruct.physics.nanTable(:,'thetaAtBase'))) > 50
                            this.checkTable{ 'physics', 'status' } = {'error: failed quality control'};
                        else
                            this.objStruct.physics.Save();
                            this.checkTable{ 'physics', 'status' } = {'computed'};
                        end
                        this.checkTable{ 'contacts', 'status' } = {'skip: no bar'};
                        this.checkTable{ 'physics', 'report' } = {this.objStruct.physics.nanTable};
                        
                    elseif strcmp(this.checkTable{'bar','status'}, 'curated')
                        % When the bar is present
                        this.objStruct.physics.Compute(...
                            'whiskerID', this.infoStruct.whiskerID, ...
                            'follicleExtrapDistInPix', this.infoStruct.distToFace, ...
                            'polyRoiInPix', this.infoStruct.polyRoiInPix, ...
                            'r_in_mm', this.infoStruct.rInMm, ...
                            'baseline_time_or_kappa_value', this.infoStruct.baselineKappaParam, ...
                            'calc_forces', true, ...
                            'whisker_radius_at_base', this.infoStruct.whiskerRadiusAtBaseInMicron, ...
                            'whisker_length', this.infoStruct.whiskerLengthInMm, ...
                            'faceSideInImage', this.infoStruct.faceSideInImage, ...
                            'protractionDirection', this.infoStruct.protractionDirection);
                        
                        % Quality control (only manual)
                        if ~this.silent
                            this.objStruct.physics.Show();
                        end
                        
                        % Save
                        if size(this.objStruct.physics.nanTable,1) > 50
                            this.checkTable{ 'physics', 'status' } = {'error: failed quality control'};
                        else
                            this.objStruct.physics.Save();
                            if ~isempty(this.objStruct.physics.wl.get_contactManual())
                                this.checkTable{ 'physics', 'status' } = {'curated'};
                            else
                                this.checkTable{ 'physics', 'status' } = {'computed'};
                            end
                        end
                        this.checkTable{ 'physics', 'report' } = {this.objStruct.physics.nanTable};
                    end
                    
                catch e
                    % Give more information for mismatch.
                    if (strcmp(e.identifier, 'Unidentified contact file ...'))
                        this.checkTable{'physics','status'} = {'error: failed to load contact file'};
                    else
                        this.checkTable{'physics','status'} = {'error: processing failed'};
                    end
                    this.checkTable{'physics','report'} = {e};
                end
            end
        end
        
        function DoPhysicsCW(this, varargin)
            p = inputParser();
            p.addParameter('Force', true, @islogical);
            p.parse(varargin{:});
            force = p.Results.Force;
            
            % Make sure all required files/data are ready
            ready = strcmp(this.checkTable{'file','status'}, 'found') ...
                && any(strcmp(this.checkTable{'measurements','status'}, {'computed','curated','found'})) ...
                && any(strcmp(this.checkTable{'bar','status'}, {'curated'}));
            
            physPath = fullfile(this.folderPath, [ this.commonName, '_WL.mat' ]);
            if exist(physPath, 'file') && ~force
                this.checkTable{ 'physics', 'status' } = {'found'};
                this.checkTable{ 'physics', 'report' } = {''};
            elseif ready
                try
                    % Compute physical quantities
                    filePath = fullfile(this.folderPath, [ this.commonName '.tif' ]);
                    this.objStruct.physics = WhisPhysCW(filePath);
                    this.objStruct.physics.Compute( ...
                        'whiskerID', this.infoStruct.whiskerID, ...
                        'follicleExtrapDistInPix', this.infoStruct.distToFace);
                    
                    % Save
                    this.objStruct.physics.Save();
                    this.checkTable{ 'physics', 'status' } = {'computed'};
                catch e
                    this.checkTable{'physics','status'} = {'error: processing failed'};
                    this.checkTable{'physics','report'} = {e};
                end
            end
        end
        
        % Contact detection
        function DetectContacts(this, classifier)
            % Contact detection
            
            if any(strcmp(this.checkTable{'physics','status'}, {'computed','curated','found'}))
                try
                    % Loading WhiskerTrialLite object
                    physicsPath = fullfile(this.folderPath, [ this.commonName, '_WL.mat' ]);
                    load(physicsPath);
                    
                    % Apply detection (Random Forest)
                    if isempty(wl.get_contactAuto()) || isempty(wl.get_contactManual())
                        wl.classify_contact(classifier);
                        disp('Classified ...');
                        
                        % Quality control
                        % TBD

                        % Save
                        save(physicsPath, 'wl', 'wst');
                    end
                    
                    this.checkTable{'contacts','status'} = {'computed'};
                    this.checkTable{'contacts','report'} = {''};
                    
                catch e
                    this.checkTable{'contacts','status'} = {'error: classification failed'};
                    this.checkTable{'contacts','report'} = {e};
                end
            end
        end
        
    end
    
end

