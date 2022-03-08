classdef PipelineBaseClass < handle
    %PIPELINEBASECLASS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        mainFolder = '';            % path of the folder where pipress is in
        pipressObj;                 % 
        classifier;
    end
    
    properties(Dependent)
        pipressPath;                % mainFolder + '\pipress'
        barGalleryFolder;           % mainFolder + '\bar_gallery'
        pipress;
    end
    
    methods
        function val = get.pipressPath(this)
            val = fullfile(this.mainFolder, 'pipress');
        end
        function val = get.barGalleryFolder(this)
            val = fullfile(this.mainFolder, 'bar_gallery');
        end
        function val = get.pipress(this)
            if ~isa(this.pipressObj, 'Pipress')
                val = [];
            else
                val = this.pipressObj.pipress;
            end
        end
    end
    
    methods
        % Default method for creating new pipress
        function CreatePipress(this, sessionDictPath, sessionDictEntryIdx)
            if nargin < 3
                sessionDictEntryIdx = 1;
            end
            
            if ~exist(this.mainFolder, 'dir')
                error('It is not a valid directory!');
            else
                % Initializes object
                this.pipressObj = Pipress();
                
                % Finds all trials to be processed
                fileList = findfiles_all_subpath(fullfile(this.mainFolder,'*.measurements'));
                [ dirList, fileNameList ] = cellfun(@fileparts, fileList, 'UniformOutput', false);
                
                % Creates pipress
                this.pipressObj.CreateNew(dirList, fileNameList, sessionDictPath, sessionDictEntryIdx);
            end
        end
        
        % Default method for loading existing pipress
        function LoadPipress(this, sessionDictPath, sessionDictEntryIdx)
            if nargin < 3
                sessionDictEntryIdx = 1;
            end
            if nargin < 2
                sessionDictPath = '';
            end
            
            if ~(exist([ this.pipressPath, '.mat' ], 'file') && exist([ this.pipressPath, '.xls' ], 'file'))
                error('A complete set of pipress needs both .mat and .xls file');
            else
                % Initializes object
                this.pipressObj = Pipress();
                
                % Loads existing pipress
                this.pipressObj.Load(this.pipressPath);
                
                % Try updating session info
                if exist(sessionDictPath, 'file')
                    this.pipressObj.FillDictionaryInfo(sessionDictPath, sessionDictEntryIdx);
                end
            end
        end
        
        % Default method for saving pipress.mat and pipress.xls
        function SavePipress(this)
            this.pipressObj.Save(this.pipressPath);
        end
        
        % Loads classifier
        function LoadClassifier(this, classifierPath)
            try
                load(classifierPath);
                this.classifier = classifier;
%                 this.classifier = cObj;
            catch
                warning('Failed to load the classifier!');
            end
        end
        
        % Save Classifier
        function SaveClassifier(this, path)
            if nargin < 2
                path = fullfile(this.mainFolder, 'classifier.mat');
            end
            classifier = this.classifier;
            save(path, 'classifier');
        end
        
    end
    
end

