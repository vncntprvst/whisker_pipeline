classdef Reviewee < matlab.mixin.Copyable
    %REVIEWEE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        trialIndex;             % index of trial in pipress
        trialFolder;            % the folder where trial data are in
        trialName;              % trial name
        
        barGalleryImgPath;      % path of PNG file in bar_gallery folder
        barGalleryImg;
        bartenderObj;
        barChanged = false;
        
        facemasks = [];
        wl;                     % Whisker.WhiskerTrialLite
    end
    
    methods
        % Constructor
        function this = Reviewee(mainFolder, trialIndex, pipressRow)
            this.trialIndex = trialIndex;
            this.trialFolder = pipressRow.dir{1};
            this.trialName = pipressRow.trialName{1};
            this.barGalleryImgPath = fullfile(mainFolder, 'bar_gallery', [ this.trialName, '.png' ]);
            
            try % in case of unstarted trial or MException object in bar_r
                this.barGalleryImg = imread(this.barGalleryImgPath);
                this.bartenderObj = Bartender('Image', this.barGalleryImg(:,:,2));
                this.bartenderObj.polePos = pipressRow.bar_r{1}.coordinate(1,:);
            catch
                this.barGalleryImg = zeros([ 480 640 3 ], 'uint8');
            end
        end
        
        function LoadFacemask(this)
            try
                load(fullfile(this.trialFolder, [ this.trialName '.facemasks' ]), '-mat');
                this.facemasks = data_faceMasks;
            catch
            end
        end
        
        function LoadPhysics(this)
            try
                load(fullfile(this.trialFolder, [ this.trialName '_WL.mat' ]), 'wl');
                this.wl = wl;
            catch
            end
        end
        
        % Change pole position
        function newPos = ChangePolePos(this, newPos)
            this.bartenderObj.polePos = newPos;
            this.barChanged = true;
        end
        
        % Save changes to files
        function success = SaveBar(this, overwrite)
            success = false;
            try
                if overwrite || ~exist(fullfile(this.trialFolder, [ this.trialName, '.bar' ]), 'file')
                    this.bartenderObj.SaveBarFile(this.trialFolder, this.trialName);
                    this.bartenderObj.SaveImage(this.barGalleryImgPath, this.barGalleryImg);
                    success = true;
                end
            catch
            end
        end
        function success = DeleteBar(this)
            success = false;
            try
                if exist(fullfile(this.trialFolder, [ this.trialName, '.bar' ]), 'file')
                    this.bartenderObj.DeleteBarFile(this.trialFolder, this.trialName);
                    success = true;
                end
            catch
            end
        end
        
        % Utilities
        function img = GetMarkedImage(this)
            img = this.barGalleryImg;
        end
        
    end
    
end

