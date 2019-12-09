classdef WhisPhys < handle
    %WHIZPHYS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        folderPath;
        commonName;
        facemasks;
        
        wt;
        wst;
        wl;
        
        nanTable;
    end
    
    methods
        function this = WhisPhys(filePath, facemasksVar)
            % Constructor
            
            if nargin > 1
                this.facemasks = facemasksVar;
            end
            [ this.folderPath, this.commonName ] = fileparts(filePath);
        end
        
        
        function Compute(this, varargin)
            % Compute physical quantities
            
            % Parse user inputs
            p = inputParser();
            
            p.addParameter('whiskerID', @isnumeric);
            
            p.addParameter('follicleExtrapDistInPix', 10, @isnumeric);
            p.addParameter('polyRoiInPix', [31 155], @isnumeric);
            p.addParameter('r_in_mm', 4, @isnumeric);
            p.addParameter('baseline_time_or_kappa_value', 0);
            
            p.addParameter('calc_forces', true, @islogical);
            p.addParameter('whisker_length', 33.5, @isnumeric);
            p.addParameter('whisker_radius_at_base', 16, @isnumeric);
            
            p.addParameter('faceSideInImage', 'bottom', @ischar);
            p.addParameter('protractionDirection', 'leftward', @ischar);
            
            p.parse(varargin{:});
            
            whiskerID = p.Results.whiskerID;
            
            follicleExtrapDistInPix = p.Results.follicleExtrapDistInPix;
            polyRoiInPix = p.Results.polyRoiInPix;
            r_in_mm = p.Results.r_in_mm;
            baseline_time_or_kappa_value = p.Results.baseline_time_or_kappa_value;
            
            calc_forces = p.Results.calc_forces;
            whisker_length = p.Results.whisker_length;
            whisker_radius_at_base = p.Results.whisker_radius_at_base;
            faceSideInImage = p.Results.faceSideInImage;
            protractionDirection = p.Results.protractionDirection;
            
            
            % Load .facemasks if not loaded yet
            if isempty(this.facemasks)
                load(fullfile(this.folderPath, [ this.commonName, '.facemasks' ]), '-mat');
                this.facemasks = data_faceMasks;
            end
            
            % Filter facemasks to eliminate interference
            cFacemasks = Masquerade.Filter(this.facemasks);
            
            
            
            % WT
            disp('Computing WhiskerTrial...');
            
            commonPath = fullfile(this.folderPath, this.commonName);
            [a, ~] = regexp(commonPath, 'Num\d*');
            trial_num = round(str2double(commonPath(a+3:end)));
            
            this.wt = Whisker.WhiskerTrial(commonPath, trial_num, whiskerID);
            this.wt.sessionName = this.commonName(1:7);
            this.wt.barRadius = 8;
            this.wt.faceSideInImage = faceSideInImage; % default = 'bottom'
            this.wt.protractionDirection = protractionDirection; % default = 'leftward'
            this.wt.imagePixelDimsXY = [640 480];
            this.wt.pxPerMm = 32.55;
            this.wt.framePeriodInSec = 0.002;
            this.wt.set_mask_from_points(whiskerID, cFacemasks(:,:,1), cFacemasks(:,:,2));
            
            
            
            % WST
            disp('Computing WhiskerSignalTrial...');
            this.wst = Whisker.WhiskerSignalTrial(this.wt, 'polyRoiInPix', polyRoiInPix);
            this.wst.recompute_cached_follicle_coords(follicleExtrapDistInPix, whiskerID); % Right now fits even "contact detection" tids, need to change format***
            
            
            
            % WL
            disp('Computing WhiskerTrialLite...');
            this.wl = Whisker.WhiskerTrialLite(this.wst, ...
                'r_in_mm', r_in_mm, ...
                'baseline_time_or_kappa_value', baseline_time_or_kappa_value, ...
                'calc_forces', calc_forces, ...
                'youngs_modulus', 5e9, ...
                'whisker_length', whisker_length, ...
                'whisker_radius_at_base', whisker_radius_at_base, ...
                'proximity_threshold', -1);
            
            if calc_forces
                % Load manual contact info if exists
                contactPath = fullfile(this.folderPath, [ this.commonName, '.contact' ]);
                xlsContactPath = fullfile(this.folderPath, [ this.commonName, '.xlsx' ]);
                if exist(contactPath, 'file') || exist(xlsContactPath, 'file')
                    this.wl.contactManual = ContactTrainer.LoadContactFile(contactPath, whiskerID);
                end
                
                % Quality control (finds NaNs)
                quants = [ ...
                    this.wl.get_position(whiskerID)', ...
                    this.wl.get_distanceToPoleCenter(whiskerID)', ...
                    this.wl.get_deltaKappa(whiskerID)' ];
                quantsNan = isnan(quants);
                
                nanRows = find(sum(quantsNan,2));
                this.nanTable = table(nanRows-1, quantsNan(nanRows,1), quantsNan(nanRows,2), quantsNan(nanRows,3), ...
                    'VariableNames', { 'frameIdx', 'thetaAtBase', 'distanceToPoleCenter', 'deltaKappa' });
                
            else
                % Quality control (finds NaNs)
                quants = [ ...
                    this.wl.get_position(whiskerID)', ...
                    this.wl.get_deltaKappa(whiskerID)' ];
                quantsNan = isnan(quants);
                
                nanRows = find(sum(quantsNan,2));
                this.nanTable = table(nanRows-1, quantsNan(nanRows,1), quantsNan(nanRows,2), ...
                    'VariableNames', { 'frameIdx', 'thetaAtBase', 'deltaKappa' });
            end
            
        end
        
        
        
        % Save and load
        function Save(this)
            wl = this.wl;
            wst = this.wst;
            save(fullfile(this.folderPath, [ this.commonName '_WL.mat' ]), 'wl', 'wst');
        end
        
        
        
        % Plot results
        function Show(this)            
            % Dist2pole and deltaKappa with NaNs
            
            normQuants = this.wl.get_contact_detection_features('normalize', true);
            frameInd = (1:size(normQuants,1))';
            figure('color','w')
            hold on
            stem(this.nanTable.frameIdx, zeros(length(this.nanTable.frameIdx), 1), 'm', 'LineWidth', 1.5);
            plot(repmat(frameInd, 1, size(normQuants,2)), normQuants);
            hold off, grid minor, pan xon, zoom xon
            legend NaNs dist2pole deltaKappa
        end
    end
    
end

