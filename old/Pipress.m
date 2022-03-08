classdef Pipress < matlab.mixin.Copyable
    %PIPRESS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        variableNames = { 'dir', 'trialName', ...
            'whiskerID', 'whiskerLength', 'whisBaseRadius', 'distToFace', 'whiskerRoi', 'r' ...
            'file', 'measurements', 'bar', 'facemasks', 'physics', 'contacts', ...
            'file_r', 'measurements_r', 'bar_r', 'facemasks_r', 'physics_r', 'contacts_r' };
    end
    
    properties
        sessionDictPath = '';
        sessionDictEntryIdx = 1;
        pipress;
    end
    
    methods
        % Constructor
        function this = Pipress()
            % do nothing
        end
        
        % Create new pipress
        function CreateNew(this, dirList, fileNameList, sessionDictPath, sessionDictEntryIdx)
            this.pipress = Pipress.GetEmptyPipress(length(dirList));
            this.pipress.dir = dirList;
            this.pipress.trialName = fileNameList;
            this.Sort();
            this.FillDictionaryInfo(sessionDictPath, sessionDictEntryIdx);
        end
        
        
        
        % Load pipress from file
        function Load(this, pipressPath)
            if nargin < 2
                pipressPath = Browse.File();
            end
            
            % Load and combine pipress from files
            load(pipressPath);
            [ ~, ~, xlsArray ] = xlsread(pipressPath);
            [ ~, order ] = natsort(xlsArray(2:end,2));
            pipress{:,1:size(xlsArray,2)} = xlsArray(order+1,:);
            oldVariableNames = pipress.Properties.VariableNames;
            
            % Initializes an empty one
            this.pipress = Pipress.GetEmptyPipress(size(pipress,1));
            
            % Fills information to the newly created empty piress which
            % allows conversion from old piress version
            for i = 1 : length(oldVariableNames)
                % Handles column renaming
                if strcmp(oldVariableNames{i}, 'tifPath')
                    oldVariableNames{i} = 'dir';
                end
                
                % Fills in data
                newColIdx = find(strcmp(oldVariableNames{i},this.variableNames));
                this.pipress.(newColIdx) = pipress.(i);
                
                % Direct literal conversion for numeric cells
                columnsToConvert = { 'whiskerID', 'whiskerLength', 'whisBaseRadius', 'distToFace', 'whiskerRoi', 'r' };
                if any(strcmp(oldVariableNames{i}, columnsToConvert))
                    charInd = cellfun(@ischar, this.pipress.(newColIdx), 'UniformOutput', false);
                    charInd = find(cell2mat(charInd));
                    this.pipress{charInd,newColIdx} = cellfun(@eval, this.pipress{charInd,newColIdx}, 'UniformOutput', false);
                end
            end
            
            % Sorts row order based on trial name
            this.Sort();
        end
        
        % Save to pipress.mat and pipress.xls
        function Save(this, pipressPath)
            if nargin < 2
                pipressPath = Browse.File();
            end
            pipress = this.pipress;
            save(pipressPath, 'pipress');
            xlswrite(pipressPath, [ this.variableNames(Pipress.GetExcelRange()); table2cell(this.GetCharPipress()) ]);
        end
        
        function charPipress = GetCharPipress(this)
            % Gets the part which goes to Excel file
            xlsRange = Pipress.GetExcelRange();
            charPipress = this.pipress(:, xlsRange);
            
            % Converts array entries into 
            infoRange = Pipress.GetSessionInfoRange();
            for i = infoRange
                charPipress.(i) = cellfun(@mat2str, this.pipress.(i), 'UniformOutput', false);
            end
            charPipress.whiskerRoi = cellfun(@mat2str, this.pipress.whiskerRoi, 'UniformOutput', false);
            charPipress.r = cellfun(@mat2str, this.pipress.r, 'UniformOutput', false);
        end
        
        
        
        % Find whisker ROI and r
        function valTrialInd = GetValPhysInd(this)
            validMask = zeros(size(this.pipress, 1),1);
            for i = 1 : size(this.pipress, 1)
                if any(strcmp(this.pipress.facemasks{i}, {'computed', 'found'})) ...
                    && any(strcmp(this.pipress.bar{i}, {'curated'}))
                    validMask(i) = 1;
                end
            end
            valTrialInd = find(validMask);
        end
        
        function [ physPipress, valTrialInd ] = GetPhysPipress(this)
            valTrialInd = this.GetValPhysInd();
            physPipress = this.pipress(valTrialInd,:);
        end
        
        function FillPhysParam(this, validInd, whiskerRoi, rInMM)
            % Reset all parameters
            this.pipress.whiskerRoi = cellfun(@(x){NaN}, this.pipress.whiskerRoi);
            this.pipress.r = cellfun(@(x){NaN}, this.pipress.r);
            
            % Set new parameters
            this.pipress.whiskerRoi(validInd) = cellfun(@(x){whiskerRoi}, this.pipress.whiskerRoi(validInd));
            this.pipress.r(validInd) = cellfun(@(x){rInMM}, this.pipress.r(validInd));
        end
        
        
        
        % Utilities
        function Sort(this)
            % Sorts entry order in pipress based on trial name
            [ ~, order ] = natsort(this.pipress.trialName);
            this.pipress = this.pipress(order, :);
        end
        
        function slices = Slice(this)
            slices = cell(size(this.pipress,1), 1);
            for i = 1 : size(this.pipress, 1)
                slices{i} = this.pipress(i,:);
            end
        end
        
        function Stack(this, pipressSlices)
            for i = 1 : size(this.pipress, 1)
                this.pipress{i,:} = pipressSlices{i}{1,:};
            end
        end
        
        function FillDictionaryInfo(this, sessionDictPath, sessionDictEntryIdx)
            % Avoids frequent access to table
            infoRange = Pipress.GetSessionInfoRange();
            sessionInfo = cell(size(this.pipress,1), length(infoRange));
            
            % Finds session information by looking up the dictionary
            [ ~, ~, xlsArray ] = xlsread(sessionDictPath);
            xlsArray = xlsArray(2:end,:);
            trialIdentifier = strsplit(this.pipress(1,:).trialName{:},'_');
            trialIdentifier = trialIdentifier{1};
            xlsKeys = xlsArray(:,1);
            trialIDs = cellfun(@(x) x(1:length(trialIdentifier)), this.pipress.trialName, 'UniformOutput', false);
            for i = 1 : size(this.pipress, 1)
                hitInd = strfind(xlsKeys, trialIDs{i});
                hitInd = cellfun(@(x) ~isempty(x), hitInd, 'Uni', false);
                hitInd = find(cell2mat(hitInd)==1);
                if hitInd
                    hitInd = hitInd(sessionDictEntryIdx);
                    sessionInfo(i,:) = xlsArray(hitInd, 2:length(infoRange)+1);
                else
                    sessionInfo(i,:) = num2cell(NaN(1, size(sessionInfo,2)));
                end
            end
            for i = 1 : size(sessionInfo,2)
                this.pipress.(infoRange(i)) = sessionInfo(:,i);
            end
        end
        
    end
    
    methods(Static)
        % Utilities
        % Gets indices that exclude report range
        function ind = GetExcelRange()
            ind = 1 : find(strcmp('file_r', Pipress.variableNames)) - 1;
        end
        % Gets indices of status and report
        function ind = GetTrialInfoRange()
            ind = [ Pipress.GetStatusRange, Pipress.GetReportRange ];
        end
        % Gets indices of status
        function ind = GetStatusRange()
            startIdx = find(strcmp('file', Pipress.variableNames));
            endIdx = find(strcmp('contacts', Pipress.variableNames));
            ind = startIdx : endIdx;
        end
        % Gets indices of report
        function ind = GetReportRange()
            startIdx = find(strcmp('file_r', Pipress.variableNames));
            ind = startIdx : length(Pipress.variableNames);
        end
        % Gets indices of session specific whisker information (ID, facemask offset, length, radius)
        function ind = GetSessionInfoRange()
            startIdx = find(strcmp('trialName', Pipress.variableNames)) + 1;
            endIdx = find(strcmp('whiskerRoi', Pipress.variableNames)) - 1;
            ind = startIdx : endIdx;
        end
        
        % Creates an empty pipress
        function eptPipress = GetEmptyPipress(numRows)
            c = repmat({'none'}, numRows, length(Pipress.variableNames));
            eptPipress = cell2table(c, 'VariableNames', Pipress.variableNames);
            dummyColumn = cell(numRows,1);
            
            startIdx = find(strcmp('whiskerID', Pipress.variableNames));
            endIdx = find(strcmp('file', Pipress.variableNames)) - 1;
            
            for i = startIdx : endIdx
                eptPipress.(i) = cellfun(@(x){NaN}, dummyColumn);
            end
        end
    end
    
end

