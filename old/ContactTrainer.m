classdef ContactTrainer < PipelineBaseClass
    %CONTACTTRAINER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        trainingColumns = { 'dir', 'trialName', 'wlObj', 'report' };
        crossvalColumns = { 'manualLabel', 'autoLabel', 'score', 'edge', 'errLabel', 'errRate' };
        bootstrpColumns = { 'numTrain', 'manualLabel', 'autoLabel', 'score', 'edge', 'errLabel', 'errRate' };
    end
    
    properties
        trainingTable;
        crossvalTable;
        bootstrpTable;
    end
    
    methods
        % Constructor
        function this = ContactTrainer(mainFolder)
            if nargin > 0
                this.mainFolder = mainFolder;
                this.LoadPipress();
            end
        end
        
        % Loads either training or testing dataset
        function LoadDataset(this, loadAll)
            if nargin < 2
                loadAll = false;
            end
            
            % Finds eligible trials
            pipress = this.pipressObj.pipress;
            eliTrialMask = zeros(size(pipress,1), 1);
            for i = 1 : size(pipress, 1)
                if StringTool.MatchRegExps(pipress.physics{i}, {'^curated'})
                    eliTrialMask(i) = 1;
                end
            end
            eliTrialInd = find(eliTrialMask);
            trialList = pipress.trialName(eliTrialInd);
            if isempty(trialList)
                error('No eligible trial (whose status in physics column is "curated") found in pipress!');
            end
            
            % Allows user to select a subset of trials
            if ~loadAll
                dlgAns = listdlg( ...
                    'ListString', trialList, ...
                    'SelectionMode', 'multiple', ...
                    'Name', 'Registration', ...
                    'ListSize', [ 400 600 ]);
                if ~isempty(dlgAns)
                    eliTrialInd = eliTrialInd(dlgAns);
                end
            end
            
            % Load trials that are eligible and selected
            dataTable = cell(length(eliTrialInd), 4);
            for i = 1 : length(eliTrialInd)
                trialIdx = eliTrialInd(i);
                
                physPath = fullfile(pipress.dir{trialIdx}, [ pipress.trialName{trialIdx}, '_WL.mat' ]);
                load(physPath);
                
                contactPath = fullfile(pipress.dir{trialIdx}, [ pipress.trialName{trialIdx}, '.contact' ]);
                wl.contactManual = ContactTrainer.LoadContactFile(contactPath, wl.trajectoryIDs(1));
                
                dataTable{i,1} = pipress.dir{trialIdx};
                dataTable{i,2} = pipress.trialName{trialIdx};
                dataTable{i,3} = { wl };
            end
            this.trainingTable = cell2table(dataTable, 'VariableNames', this.trainingColumns);
        end
        
        % Pooling data across trials
        function features = GetFeatures(this, ind)
            if nargin < 2
                ind = 1 : size(this.trainingTable,1);
            end
            features = cellfun(@(x) x.get_contact_detection_features('order', 2, 'wingSize', 2, 'fixNaN', true), ...
                this.trainingTable.wlObj(ind), 'UniformOutput', false);
            features = cell2mat(features);
        end
        function labels = GetManualLabels(this, ind)
            if nargin < 2
                ind = 1 : size(this.trainingTable,1);
            end
            labels = cell2mat(cellfun(@(x) x.get_contactManual()', this.trainingTable.wlObj(ind), 'Uni', false));
        end
        function labels = GetAutoLabels(this, ind)
            if nargin < 2
                ind = 1 : size(this.trainingTable,1);
            end
            labels = cell2mat(cellfun(@(x) x.get_contactAuto()', this.trainingTable.wlObj(ind), 'Uni', false));
        end
        function amp = GetAmplitudes(this, ind)
            if nargin < 2
                ind = 1 : size(this.trainingTable,1);
            end
            amp = cellfun(@(x) x.get_amplitude()', this.trainingTable.wlObj(ind), 'Uni', false);
            frameInd = cellfun(@(x) x.get_frameInd()', this.trainingTable.wlObj(ind), 'Uni', false);
            for i = length(amp) : -1 : 1
                tempVect = NaN(2500,1);
                tempVect(frameInd{i}) = amp{i};
                amp{i} = MMath.InterpNaN(tempVect);
                if all(isnan(amp{i}))
                    amp{i}(:) = 0;
                end
            end
            amp = cell2mat(amp);
        end
        
        % Trains Random Forest
        function Train(this)
            numTree = 300;
            this.classifier = TreeBagger( ...
                numTree, ...
                this.GetFeatures(), ...
                this.GetManualLabels(), ...
                'OOBPred', 'on', ...
                'Method', 'classification', ...
                'MinLeaf', 1);
        end
        
        % Tests Classifier
        function Test(this, mode, numIter, numTrain)
            if nargin < 3
                numIter = 20;
            end
            if nargin < 4
                numTrain = 1 : 3 : size(this.trainingTable,1)-3;
            end
            if max(numTrain) == size(this.trainingTable,1)
                error('You have to spare some trials for testing purpose!');
            end
            
            switch mode
                case 'oob'
                    % Test on out-of-bag training data
                    [ resultLabel, score ] = oobPredict(this.classifier);
                    
                    % Parse the single array into cell array of trials
                    resultLabel = mat2cell(resultLabel, repmat(2500, length(resultLabel)/2500, 1));
                    resultLabel = cellfun(@(x) double(cell2mat(x) - '0'), resultLabel, 'UniformOutput', false);
                    score = mat2cell(score, repmat(2500, length(score)/2500, 1));
                    
                    for i = 1 : length(resultLabel)
                        % Sets result into WhiskerTrialLite objects
                        this.trainingTable.wlObj{i}.contactAuto = { resultLabel{i}' };
                        this.trainingTable.wlObj{i}.contactScore = { score{i}' };
                        
                        % Updates report column in dataTable
                        cmpStruct = this.trainingTable.wlObj{i}.compare_contacts();
                        this.trainingTable.report{i} = cmpStruct.errRate;
                    end
                    
                case 'kfold'
                    % Test by K-fold cross-validation
                    totalTrials = size(this.trainingTable,1);
                    c = cvpartition(totalTrials, 'KFold', numIter);
                    valiResults = cell(c.NumTestSets, length(this.crossvalColumns));
                    
                    % Configures and starts parpool
                    try
                        parpool('local');
                    catch
                        disp('Using existing parallel session...');
                    end
                    
                    parfor k = 1 : c.NumTestSets
                        disp(k);
                        tic
                        cmpStruct = this.ValidationFunc(c.training(k), c.test(k));
                        valiResults(k,:) = struct2cell(cmpStruct)';
                        toc
                    end
                    
                    this.crossvalTable = cell2table(valiResults, 'VariableNames', this.crossvalColumns);
                    
                case 'bootstrap'
                    % Test by bootstrap
                    totalTrials = size(this.trainingTable,1);
                    bsResults = cell(length(numTrain)*numIter, length(this.bootstrpColumns));
                    
                    % Configures and starts parpool
                    try
                        parpool('local');
                    catch
                        disp('Using existing parallel session...');
                    end
                    
                    for kk = 1 : length(numTrain)
                        tierResult = cell(numIter, length(this.bootstrpColumns));
                        for k = 1 : numIter
                            fprintf('Training %d, round %d ', numTrain(kk), k);
                            tic
                            pInd = randperm(totalTrials);
                            cmpStruct = this.ValidationFunc(pInd(1:numTrain(kk)), pInd(numTrain(kk)+1:end));
                            tierResult(k,:) = [ numTrain(kk), struct2cell(cmpStruct)'];
                            toc
                        end
                        bsResults((kk-1)*numIter+1 : kk*numIter, :) = tierResult;
                    end
                    
                    % Combines with previous results
                    if ~isempty(this.bootstrpTable)
                        this.bootstrpTable = [ this.bootstrpTable; cell2table(bsResults, 'VariableNames', this.bootstrpColumns) ];
                        [ ~, ind ] = sort(this.bootstrpTable.numTrain);
                        this.bootstrpTable = this.bootstrpTable(ind,:);
                    else
                        this.bootstrpTable = cell2table(bsResults, 'VariableNames', this.bootstrpColumns);
                    end
            end
        end
        
        % Plots Classifier Performance
        function ShowOobErr(this)
            plot(oobError(this.classifier));
        end
        function ShowOobComparison(this, range)
            if nargin < 2
                range = 1;
            end
            wlObj = this.trainingTable.wlObj(range);
            cellfun(@disp, this.trainingTable.trialName(range));
            
            % Contact detection info
            cmpStructs = cellfun(@(x) x.compare_contacts(), wlObj, 'UniformOutput', false);
            errLabel = cell2mat(cellfun(@(x) x.errLabel, cmpStructs, 'UniformOutput', false));          % Indices of error labels
            trueLabel = cell2mat(cellfun(@(x) x.manualLabel, cmpStructs, 'UniformOutput', false));      % True labels
            score = cell2mat(cellfun(@(x) x.scores, cmpStructs, 'UniformOutput', false));               % Scores of auto-detection
            
            % Physical quantities and indices of missing data points
            [ features, nans ] = cellfun(@(x) x.get_contact_detection_features('normalize', true), ...
                wlObj, 'UniformOutput', false);
            quants = cell2mat(features);
            indNaN = find(sum(cell2mat(nans),2)) - 1;
            
            % x axis
            x = 0 : size(quants,1)-1;
            % Confidence
            plot(x, score, 'k', 'LineWidth', 1.5);
            hold on;
            % Manual labeling
            stem(x, trueLabel, '.', 'Color', [.8 .8 .8], 'LineWidth', 1.5, 'MarkerSize', 16);
            % Different labeling
            indErrLabel = find(errLabel) - 1;
            stem(indErrLabel, ones(size(indErrLabel)), 'r', 'LineWidth', 1.5);
            % Normailized quantities
            plot(x, quants);
            % Missing frames
            scatter(indNaN, zeros(size(indNaN)), 'm', 'LineWidth', 1.5);
            
            xlim([ 0 x(end) ]);
            hold off, grid minor, pan xon, zoom xon, axis tight
            legend Score True Mistake Dist2Pole DeltaKappa Missing
            xlabel('frames (concatenated)');
            ylabel('normalized quantities');
        end
        function ShowOobTransitionErr(this, winRoi)
            if nargin < 2
                winRoi = -1 : 0;
            end
            
            p = this.CompareTransitions(winRoi, this.GetManualLabels(), this.GetAutoLabels(), this.GetAmplitudes());
            
            figure(585274); clf
            subplot(2,2,1)
            bar(p.winRoi, [ p.riseNeg, p.risePos ], 'stacked');
            legend FalseNegative FalsePositive
            ylabel('Conditional probability P(error|an onset frame)');
            title('Error probability around contact onsets', 'FontSize', 12);
            xlim([ winRoi(1)-1, winRoi(end)+1 ]);
            
            subplot(2,2,2)
            bar(p.winRoi, [ p.fallNeg, p.fallPos ], 'stacked');
            legend FalseNegative FalsePositive
            ylabel('Conditional probability P(error|an offset frame)');
            title('Error probability around contact offsets', 'FontSize', 12);
            xlim([ winRoi(1)-1, winRoi(end)+1 ]);
            
            subplot(2,2,[3 4])
            bar([ p.edgeErrRate, p.totalErrRate-p.edgeErrRate ] / sum(p.totalErrRate));
            ylim([0 1]);
            set(gca, 'XTickLabel', {'TransFalsePos' 'TransFalseNeg' 'OtherFalsePos' 'OtherFalseNeg'});
            ylabel('Conditional probability P(error type|error)');
            title(['Error breakdown (Total error probability = ' num2str(sum(p.totalErrRate)) ')'], 'FontSize', 12);
        end
        function ShowBootstrapErr(this, showAUC)
            if nargin < 2
                showAUC = false;
            end
            numRun = size(this.bootstrpTable,1);
            
            if showAUC
                [ ~, ~, ~, aucs ] = arrayfun(@(x) ...
                    perfcurve(this.bootstrpTable.manualLabel{x}, this.bootstrpTable.score{x}(:,2), 1), (1:numRun)', ...
                    'UniformOutput', false);
                aucs = cell2mat(aucs);
            else
                aucs = zeros(size(this.bootstrpTable.numTrain));
            end
            
            numTrain = unique(this.bootstrpTable.numTrain);
            for i = length(numTrain) : -1 : 1
                numIter = 0;
                sumError = [ 0 0 ];
                sumAuc = 0;
                for j = 1 : numRun
                    if this.bootstrpTable.numTrain(j) == numTrain(i)
                        sumError = sumError + this.bootstrpTable.errRate(j,:);
                        sumAuc = sumAuc + aucs(j);
                        numIter = numIter + 1;
                    end
                end
                meanErrorRate(i,:) = sumError / numIter;
                meanAucs(i) = sumAuc / numIter;
            end
            
            figure(585275); clf
            hold on
            plot(numTrain, [ sum(meanErrorRate,2) meanErrorRate ]);
            legend Total FalseNegative FalsePositive
            plot(this.bootstrpTable.numTrain, sum(this.bootstrpTable.errRate, 2), 'ko');
            hold off
            ylabel('Error probability');
            xlabel('#Trials used for training');
            
            if showAUC
                figure
                hold on
                plot(this.bootstrpTable.numTrain, aucs, 'o');
                plot(numTrain, meanAucs, 'Color', [ .7 .7 .7 ]);
                hold off
                ylabel('AUC');
                xlabel('#Trials used for training');
            end
        end
        
        % Save Trials
        function SaveTrials(this)
            for i = 1 : size(this.trainingTable,1)
                path = fullfile(this.trainingTable.dir{i}, [ this.trainingTable.trialName{i}, '_WL.mat' ]);
                load(path, 'wst');
                wl = this.trainingTable.wlObj{i};
                save(path, 'wl', 'wst');
            end
            disp('All trials from training dataset are saved');
        end
        function SaveObject(this, folderPath, sessionName)
            if nargin < 2 || isempty(folderPath)
                folderPath = this.mainFolder;
            end
            if ~isempty(this.trainingTable)
                if nargin < 3
                    sessionName = this.trainingTable.wlObj{1}.sessionName;
                end
                ct = this;
                save(fullfile(folderPath, [ 'ContactTrainer_' sessionName ]), 'ct');
                disp('The current ContactTrainer object is saved.');
            end
        end
    end
    
    
    
    methods(Access = private)
        % The core function for model validation
        function cmpStruct = ValidationFunc(this, trainInd, testInd)
            numTree = 300;
            baggerObj = TreeBagger( ...
                numTree, ...
                this.GetFeatures(trainInd), ...
                this.GetManualLabels(trainInd), ...
                'Method', 'classification', ...
                'MinLeaf', 1);
            
            [ resultLabel, score ] = baggerObj.predict(this.GetFeatures(testInd));
            
            cmpStruct = this.CompareConatcts( ...
                this.GetManualLabels(testInd), double(cell2mat(resultLabel) - '0'), score, this.GetAmplitudes(testInd));
        end
    end
    
    
    
    methods(Static)
        % Basic comparison between manual and auto contact detection
        function cmpStruct = CompareConatcts(manualLabel, autoLabel, score, amp)
            cmpStruct.manualLabel = manualLabel;
            cmpStruct.autoLabel = autoLabel;
            cmpStruct.score = score;
            cmpStruct.edge = [ 0; diff(cmpStruct.manualLabel) ];
            cmpStruct.errLabel = autoLabel - manualLabel;
            
            if nargin > 3
                ampMask = amp < 2.5;
                cmpStruct.errLabel(ampMask) = 0;
                cmpStruct.errRate = [ sum(cmpStruct.errLabel == 1), sum(cmpStruct.errLabel == -1) ] / sum(~ampMask);
            else
                cmpStruct.errRate = [ sum(cmpStruct.errLabel == 1), sum(cmpStruct.errLabel == -1) ] / length(manualLabel);
            end
        end
        
        % Analysis on contact onsets and offsets
        function transStruct = CompareTransitions(winRoi, manualLabel, autoLabel, amp)
            % Gets basic information
            numFrame = length(manualLabel);
            transitions = [ 0; diff(manualLabel) ];
            transitions(1:2500:length(manualLabel)) = 0;    % removes "transitions" on trial boundaries
            errLabel = autoLabel - manualLabel;
            
            % Optionally removes results with small amplitude
            if nargin > 3
                ampMask = amp < 2.5;
                transitions(ampMask) = 0;
                errLabel(ampMask) = 0;
                errRate = [ sum(errLabel == 1), sum(errLabel == -1) ] / sum(~ampMask);
            else
                errRate = [ sum(errLabel == 1), sum(errLabel == -1) ] / numFrame;
            end
            
            % Finds a set of indices for each ROI
            riseInd = find(transitions == 1);
            fallInd = find(transitions == -1);
            riseRoiInd = MMath.Ind2Roi(riseInd, winRoi, [ 1, numFrame ]);
            fallRoiInd = MMath.Ind2Roi(fallInd, winRoi, [ 1, numFrame ]);
            
            % Masks out errors in other regions
            roiInd = zeros(numFrame, 1);
            roiInd([ riseRoiInd(:); fallRoiInd(:) ]) = 1;
            transErrLabel = errLabel .* roiInd;
            
            % Finds error labels in each ROI
            riseErr = errLabel(riseRoiInd);
            fallErr = errLabel(fallRoiInd);
            
            % Separates false positive and false negative
            risePos = zeros(size(riseErr));
            risePos(riseErr == 1) = 1;
            riseNeg = zeros(size(riseErr));
            riseNeg(riseErr == -1) = 1;
            
            fallPos = zeros(size(fallErr));
            fallPos(fallErr == 1) = 1;
            fallNeg = zeros(size(fallErr));
            fallNeg(fallErr == -1) = 1;
            
            % Fills final results into struct
            transStruct.winRoi = winRoi;
            transStruct.risePos = mean(risePos)';
            transStruct.riseNeg = mean(riseNeg)';
            transStruct.fallPos = mean(fallPos)';
            transStruct.fallNeg = mean(fallNeg)';
            transStruct.totalErrRate = errRate;
            transStruct.edgeErrRate = [ sum(transErrLabel == 1), sum(transErrLabel == -1) ] / numFrame;
        end
        
        % Loads contact file (and updates file format when necessary)
        function [ labels, c ] = LoadContactFile(contactPath, trajectoryID, updateVersion)
            % Update contact file version (when applicable) by default
            if nargin < 3
                updateVersion = true;
            end
            updatable = false;
            
            [ folderPath, fileName ] = fileparts(contactPath);
            contactPath = fullfile(folderPath, [ fileName, '.contact' ]);
            disp(fileName);
            
            % Converts all other versions to MATLAB version
            try
                % Try handling the MATLAB version
                load(contactPath, '-mat');
                labels = c.contact.(1);
                disp('Loaded MATLAB file');
            catch
                try
                    % Try handling EXCEL version
                    xlsArray = xlsread(fullfile(folderPath, [ fileName, '.xlsx' ]));
                    labels = xlsArray(:,2);
                    disp('Loaded Excel file');
                catch
                    % Handles two formatted text versions
                    fileID = fopen(contactPath, 'r');
                    labels = textscan(fileID, '%s', 'Delimiter', '\n');
                    fclose(fileID);
                    
                    labels = labels{1};
                    if length(labels) == 2500
                        labels = round(str2double(labels));
                        disp('Loaded formated file');
                    elseif length(labels) == 2501
                        metadata = labels{1};
                        c.detector = metadata(3:4);
                        c.trajectory = str2double(metadata(6));
                        c.date = metadata(8:end);
                        labels = round(str2double(labels(2:end)));
                        disp('Loaded formated file with header');
                    end
                end
                c.contact = table(labels, 'VariableNames', { 'contact' });
                updatable = true;
            end
            
            % Check data integrity
            if ~isfield(c, 'trajectory')
                c.trajectory = [];
                updatable = true;
            elseif ischar(c.trajectory)
                c.trajectory = str2double(c.trajectory);
                updatable = true;
            end
            if ~isfield(c, 'detector')
                c.detector = '';
                updatable = true;
            end
            if ~isfield(c, 'date')
                c.date = '';
                updatable = true;
            end
            
            % Save the updated version
            if updateVersion && updatable
                save(contactPath, 'c');
                disp('Updated contact file format');
            end
            
            % Returns labels based on user input
            if nargin < 2 || isempty(trajectoryID)
                ind = 1:size(labels,2);
            else
                if ~isfield(c, 'trajectory') || length(c.trajectory) ~= size(labels,2)
                    error('The .contact file need to be updated with additional info ...');
                end
                ind = find(c.trajectory == trajectoryID);
            end
            labels = mat2cell(labels(:,ind)', ones(length(ind),1));
        end
        
        % Updates info in contact file
        function c = UpdateContactFileInfo(contactPath, varargin)
            % Parse user inputs
            p = inputParser();
            p.addParameter('trajectory', [], @isnumeric);
            p.addParameter('detector', '', @ischar);
            p.addParameter('date', '', @ischar);
            p.addParameter('checkOnly', false, @islogical);
            p.addParameter('forcedPrompt', false, @islogical);
            p.parse(varargin{:});
            checkOnly = p.Results.checkOnly;
            forcedPrompt = p.Results.forcedPrompt;
            
            % Load contact file
            [ ~, c ] = ContactTrainer.LoadContactFile(contactPath, [], ~checkOnly);
            [ ~, fileName ] = fileparts(contactPath);
            updatable = false;
            
            % Updates info with optional function inputs
            if length(p.Results.trajectory) == size(c.contact.(1), 2)
                c.trajectory = p.Results.trajectory;
                updatable = true;
            end
            if ~isempty(p.Results.detector)
                c.detector = p.Results.detector;
                updatable = true;
            end
            if ~isempty(p.Results.date)
                c.date = p.Results.date;
                updatable = true;
            end
            
            % Updates info using GUI prompt
            if length(c.trajectory) ~= size(c.contact.(1), 2) || isempty(c.detector) || isempty(c.date) || forcedPrompt
                % Keeps asking user until inputs are valid or user cancels
                toExit = false;
                while ~toExit
                    % Prompts input dialog
                    prompt = {'Trajectories: ', 'Detector: ', 'Date: '};
                    ansCfg = inputdlg(prompt, fileName, [ 1 100 ], { mat2str(c.trajectory), c.detector, c.date });
                    
                    % Handles user inputs
                    if checkOnly
                        toExit = true;
                        updatable = true;
                    else
                        if ~isempty(ansCfg)
                            % Fills in the putative info
                            c.trajectory = eval([ '[' ansCfg{1} ']' ]);
                            c.detector = ansCfg{2};
                            c.date = ansCfg{3};

                            % Tests the validity
                            toExit = length(c.trajectory) == size(c.contact.(1), 2) && ~isempty(c.detector) && ~isempty(c.date);

                            % Changes status
                            if toExit
                                updatable = true;
                            end
                        else
                            toExit = true;
                        end
                    end
                end
            end
            
            % Updates file info
            if updatable
                if checkOnly
                    disp('The information is not complete!');
                else
                    save(contactPath, 'c');
                    disp('New contact file is saved!');
                end
            else
                disp('Nothing to fill in (or user canceled) ...');
            end
        end
        
        % Updates labels in contact file
        function c = UpdateContactFileLabels(contactPath, newLabels, wid)
            % Load contact file
            [ ~, c ] = ContactTrainer.LoadContactFile(contactPath);
            [ ~, fileName ] = fileparts(contactPath);
            disp(fileName);
            
            if nargin < 3
                wid = c.trajectory;
            end
            
            if size(newLabels,2) > size(newLabels,1)
                newLabels = newLabels';
            end
            
            % Updates labels
            updatable = false;
            if size(newLabels,1) == 2500 && size(newLabels,2) == length(wid)
                allLabels = c.contact.(1);
                for i = 1 : length(wid)
                    k = find(c.trajectory == wid(i));
                    if ~isempty(k)
                        % Trajectory exists
                        allLabels(:, k) = newLabels(:, i);
                    else
                        % This is a new trajectory
                        c.trajectory(end+1) = wid(i);
                        allLabels = [ allLabels, newLabels(:, i) ];
                    end
                    updatable = true;
                end
                c.contact.(1) = allLabels;
            end
            
            if updatable
                % Save contact file
                save(contactPath, 'c');
                disp('Updated contact file is saved!');
            else
                error('Incorrect input(s)');
            end
        end
        
        % Save contact file
        function c = SaveContactFile(contactPath, varargin)
            % Parse user inputs
            p = inputParser();
            p.addRequired('labels');
            p.addParameter('trajectory', [], @isnumeric);
            p.addParameter('detector', '', @ischar);
            p.addParameter('date', date, @ischar);
            p.parse(varargin{:});
            
            % Make sure labels are column vectors
            labels = p.Results.labels;
            if size(labels,1) < size(labels,2)
                labels = labels';
            end
            
            c.contact = table(labels, 'VariableNames', { 'contact' });
            c.trajectory = p.Results.trajectory;
            c.detector = p.Results.detector;
            c.date = p.Results.date;
            
            % Updates info using GUI prompt
            if length(c.trajectory) ~= size(c.contact.(1), 2) || isempty(c.detector) || isempty(c.date)
                % Keeps asking user until inputs are valid or user cancels
                toExit = false;
                while ~toExit
                    % Prompts input dialog
                    prompt = {'Trajectories: ', 'Detector: ', 'Date: '};
                    ansCfg = inputdlg(prompt, 'Info', [ 1 50 ], { mat2str(c.trajectory), c.detector, c.date });
                    
                    % Handles user inputs
                    if ~isempty(ansCfg)
                        % Fills in the putative info
                        c.trajectory = eval([ '[' ansCfg{1} ']' ]);
                        c.detector = ansCfg{2};
                        c.date = ansCfg{3};
                        
                        % Tests the validity
                        toExit = length(c.trajectory) == size(c.contact.(1), 2) && ~isempty(c.detector) && ~isempty(c.date);
                    else
                        toExit = true;
                    end
                end
            end
            
            % Updates file info
            if length(c.trajectory) == size(c.contact.(1), 2) && ~isempty(c.detector) && ~isempty(c.date)
                save(contactPath, 'c');
                disp('The .contact file is saved!');
            else
                disp('Incomplete information. Contact file NOT saved!');
            end
        end
    end
end

