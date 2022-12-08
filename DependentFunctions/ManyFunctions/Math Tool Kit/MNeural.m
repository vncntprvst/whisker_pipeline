classdef MNeural
    %MMATH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods(Static)
        
        function tunings = Tuning(varargin)
            %Computes tuning curves (and errors) for given stimuli
            %
            %   tunings = Tuning()
            %   tunings = Tuning(stimuli)
            %   tunings = Tuning(stimuli, response)
            %   tunings = Tuning(..., 'mask', logicals)
            %   tunings = Tuning(..., 'numBins', value)
            %   tunings = Tuning(..., 'rmMethod', options)
            %   tunings = Tuning(..., 'rmParam', params)
            %   
            % Inputs:
            %   stimuli         Data of stimuli (each column is one stimulus)
            %   response        Array of spike rates corresponding to the stimuli.
            %   'mask'          Numeric or cell array of binary indices used to mask data. (default is no masking)
            %   'numBins'       Number of bins used to group the stimuli range (default is 50)
            %   'rmMethod'      A string (or a cell array of strings) specifying the method of outlier removal for 
            %                   all (or individual) stimulus variable (default 'percentile', other methods include
            %                   'std', 'whisker', 'cut'). See help of MMath.RemoveOutliers() for more details. 
            %   'rmParam'       Parameter(s) for outlier removal (default NaN, no outlier removal). You may provide an array of row 
            %                   vectors that specify parameters for individual stimulus variables. See the help
            %                   of MMath.RemoveOutliers() for more details. 
            % Output:
            %   tunings         Cell array of tuning curves, each contains 4 column vectors - bin centers, 
            %                   mean firing rate, standard error of the mean, and number of samples - from 1 to 4.
            
            % Handles user inputs
            p = inputParser();
            p.addRequired('stimuli');
            p.addRequired('response');
            p.addParameter('mask', []);
            p.addParameter('numBins', 50, @isscalar);
            p.addParameter('rmMethod', 'percentile');
            p.addParameter('rmParam', NaN, @isnumeric);
            p.addParameter('tfParam', NaN, @isnumeric);
            p.parse(varargin{:});
            stim = MNeural.Vars2Mat(p.Results.stimuli);
            resp = MNeural.Vars2Mat(p.Results.response);
            dataMask = p.Results.mask;
            numBins = p.Results.numBins;
            rmParam = p.Results.rmParam;
            rmMethod = cellstr(p.Results.rmMethod);
            tfParam = p.Results.tfParam;
            
            if size(stim,1) ~= length(resp)
                error([ 'The length of stimuli does not match with that of the spike rates. ', ...
                    'If you are not using the full length of stimuli, ', ...
                    'the corresponding array of spike rates needs to be provided.' ]);
            end
            
            % Propagates settings
            if length(numBins) < size(stim,2)
                numBins(end+1:size(stim,2),1) = numBins(1);
            end
            if size(rmParam,1) < size(stim,2)
                rmParam = repmat(rmParam(1,:), size(stim,2), 1);
            end
            if length(rmMethod) < size(stim,2)
                rmMethod = repmat(rmMethod(1), size(stim,2), 1);
            end
            if ~isempty(tfParam) && size(tfParam,1) < size(stim,2)
                tfParam = repmat(tfParam(1), size(stim,2), 1);
            end
            
            % Data masking
            if ~isempty(dataMask)
                if iscell(dataMask)
                    dataMask = cell2mat(dataMask);
                end
                if size(stim,1) ~= length(dataMask)
                    error('The length of stimuli does not match with that of the mask.');
                end
                dataMask = logical(dataMask);
                stim = stim(dataMask, :);
                resp = resp(dataMask);
            end
            
            % Tansform data
            for i = size(stim,2) : -1 : 1
                if isnan(tfParam(i))
                    f{i} = @(x) x;
                    fi{i} = @(y) y;
                else
                    k = 1 / prctile(stim(:,i), tfParam(i));
                    f{i} = @(x) 2./(1 + exp(-k*x)) - 1;
                    fi{i} = @(y) -1/k * (log(1-y) - log(1+y));
                    stim(:,i) = f{i}(stim(:,i));
                end
            end
            
            % Computes for each stimulus
            for i = size(stim,2) : -1 : 1
                % Removes outliers in the stimulus vector and corresponding entries in response vector
                [ stimClean, indKeep ] = MMath.RemoveOutliers(stim(:,i), rmParam(i,:), rmMethod{i});
                respClean = resp(indKeep);
                
                % Bining response by stimulus value ranges
                edges = linspace(min(stimClean), max(stimClean), numBins(i)+1);
                centers = mean([ edges(1:end-1); edges(2:end) ]);
                [ ~, binInd ] = histc(stimClean, edges);
                for j = length(edges)-1 : -1 : 1
                    ratesVect = respClean(binInd == j);
                    numSample = numel(ratesVect);
                    if numSample == 0
                        meanSpikeRate = 0;
                        steSpikeRate = 0;
                    else
                        meanSpikeRate = nanmean(ratesVect);
                        steSpikeRate = MMath.StandardError(ratesVect);
                    end
                    binNumSample(j) = numSample;
                    binMeanSpikeRate(j) = meanSpikeRate;
                    binSteSpikeRate(j) = steSpikeRate;
                end
                
                % Transforms axes back
                centers = fi{i}(centers);
                
                tunings{i,1} = [ centers; binMeanSpikeRate; binSteSpikeRate; binNumSample ]';
            end
        end
        
        function t = JointTuning(varargin)
            % Calculates the joint probability distribution of multiple random variables
            %
            %   t = GetJointDist(stimuli)
            %   t = GetJointDist(stimuli, response)
            %   t = GetJointDist(..., 'mask', logicals)
            %   t = GetJointDist(..., 'numBins', numbers)
            %   t = GetJointDist(..., 'rmMethod', options)
            %   t = GetJointDist(..., 'rmParam', params)
            %   
            % Inputs:
            %   stimuli         Data of stimuli (each column is one stimulus).
            %   response        Array of responses corresponding to the stimuli.
            %   'mask'          Numeric or cell vector of binary indices used to mask selected data. (default is
            %                   no masking)
            %   'numBins'       Number of bins used to group the stimuli range (default is 30). Use NaN to
            %                   specify catagorical variable.
            %   'rmMethod'      A string (or a cell array of strings) specifying the method of outlier removal for 
            %                   all (or individual) stimulus variable (default 'percentile', other methods include
            %                   'std', 'whisker', 'cut'). See help of MMath.RemoveOutliers() for more details. 
            %   'rmParam'       Parameter(s) for outlier removal (default 0.5). You may provide an array of row 
            %                   vectors that specify parameters for individual stimulus variables. See the help
            %                   of MMath.RemoveOutliers() for more details. 
            % Output:
            %   t               A struct of various tuning information
            
            % Handle user input
            p = inputParser();
            p.addRequired('stimuli');
            p.addRequired('response');
            p.addParameter('mask', []);
            p.addParameter('numBins', 30, @isnumeric);
            p.addParameter('rmParam', .5, @isnumeric);
            p.addParameter('rmMethod', 'percentile');
            p.addParameter('tfParam', NaN, @isnumeric);
            p.parse(varargin{:});
            stim = MMath.Vars2Mat(p.Results.stimuli);
            resp = MMath.Vars2Mat(p.Results.response);
            dataMask = p.Results.mask;
            numBins = p.Results.numBins;
            rmParam = p.Results.rmParam;
            rmMethod = cellstr(p.Results.rmMethod);
            tfParam = p.Results.tfParam;
            
            % Propagate settings
            if length(numBins) < size(stim,2)
                numBins(end+1:size(stim,2),1) = numBins(1);
            end
            if length(rmMethod) < size(stim,2)
                rmMethod = repmat(rmMethod(1), size(stim,2), 1);
            end
            if size(rmParam,1) < size(stim,2)
                rmParam = repmat(rmParam(1,:), size(stim,2), 1);
            end
            if ~isempty(tfParam) && size(tfParam,1) < size(stim,2)
                tfParam = repmat(tfParam(1), size(stim,2), 1);
            end
            
            % Data masking
            if ~isempty(dataMask)
                if iscell(dataMask)
                    dataMask = cell2mat(dataMask);
                end
                dataMask = logical(dataMask);
                stim = stim(dataMask, :);
                resp = resp(dataMask, :);
            end
            
            % Tansform data
            for i = size(stim,2) : -1 : 1
                if isnan(tfParam(i))
                    f{i} = @(x) x;
                    fi{i} = @(y) y;
                else
                    k = 1 / prctile(stim(:,i), tfParam(i));
                    f{i} = @(x) 2./(1 + exp(-k*x)) - 1;
                    fi{i} = @(y) -1/k * (log(1-y) - log(1+y));
                    stim(:,i) = f{i}(stim(:,i));
                end
            end
            
            % Remove outliers
            indClean = true(size(stim,1), 1);
            for i = 1 : size(stim,2)
                [ ~, varMaskKeep ] = MMath.RemoveOutliers(stim(:,i), rmParam(i,:), rmMethod{i});
                indClean = indClean & varMaskKeep;
            end
            
            % Bin variables
            randVars = [stim, resp];
            randVars = randVars(indClean, :);
            if length(numBins) <= size(stim,2)
                numBins(size(stim,2)+1) = NaN;
            end
            [t.jointProb, t.binCenters, binCoor] = MMath.JointDist(randVars, numBins);
            
            t.condProb = MMath.ConditionalDist(t.jointProb, 1:size(stim,2));                % P(resp|stim)
            t.condExp = MMath.Expectation(t.condProb, t.binCenters{end}, size(stim,2)+1);   % E(resp|stim)
            
            binCoor = num2cell(binCoor, 1);
            indSample = sub2ind(size(t.condExp), binCoor{1:end-1});
            t.sampleVal = arrayfun(@(x) randVars(indSample==x,end), (1:numel(t.condExp))', 'Uni', false);
            t.sampleVal = reshape(t.sampleVal, size(t.condExp));
            t.sampleSE = cellfun(@MMath.StandardError, t.sampleVal);
            
            t.margProb = sum(t.jointProb, ndims(t.jointProb));                              % P(stim)
            t.sampleNum = round(t.margProb * sum(indClean));
            t.sampleLog = log10(t.sampleNum);
            t.sampleLog(t.sampleLog == -Inf) = NaN;
            
            t.condExpClean = t.condExp;
            t.condExpClean(t.sampleNum < 25) = NaN;
            
            % Transform back
            for i = size(stim,2) : -1 : 1
                t.binCenters{i} = fi{i}(t.binCenters{i});
            end
        end
    end
    
    
    
    methods(Static, Access = private)
        function vars = Vars2Mat(vars)
            % Converts heterogeneous and/or nested variable specifications to homogeneous numeric array
            %
            %   vars = Vars2Mat(vars)
            %   
            % Inputs
            %   vars            Data of stimuli (each column is one stimulus).
            % Output:
            %   vars            Homogeneous numeric array of column vectors
            
            try
                if iscell(vars)
                    % Nested cell array
                    if isvector(vars)
                        for i = 1 : length(vars)
                            % De-nesting
                            if iscell(vars{i})
                                vars{i} = cell2mat(vars{i});
                            end
                        end
                    end
                    % Cell array
                    vars = cell2mat(vars);
                end
            catch
                error('The input cannot be resolved. Please check for the consistency of potential length of each column.');
            end
        end
        
    end
end

