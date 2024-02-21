classdef MMath
    %MMATH Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods(Static)
        function [ci, statDist] = BootCI(nboot, bootfun, vect, varargin)
            %Removes outliers
            %
            %   [ vect, indKept, lims ] = RemoveOutliers(vect)
            %   [ vect, indKept, lims ] = RemoveOutliers(vect, boundParam)
            %   [ vect, indKept, lims ] = RemoveOutliers(vect, boundParam, method)
            %
            % Inputs:
            %   vect            A vector of numeric data
            %   boundParam      Either (1) a positive scaler of the number of deviation or (2) a tuple specifying the 
            %                   numbers of deviation on each side respectively (e.g. [ numLower, numUpper ]).
            %                   The default for standard deviation is [ 3 3 ], for whisker is [ 1.5 1.5 ], for
            %                   percentile is [ 0.1 0.1 ].
            %   method          'std' for removal based on the number of standard deviation (default); 
            %                   'whisker' based on the number of difference of 25 to 75 percentile value (same 
            %                   convention as MATLAB's built-in whisker plot);
            %                   'percentile' removes the specified lower and upper percentage of data; 
            %                   'cut' uses actual cutoff thresholds to remove outliers.
            % Output: 
            %   vect            The vector without outliers
            %   indKept         The binary indices of values being kept
            %   lims            A tuple containing values of lower and upper limit used for removal
            
            % Handles user inputs
            p = inputParser();
            p.addParameter('alpha', 0.05, @(x) isscalar(x) && x<1 && x>0);
            p.parse(varargin{:});
            a = p.Results.alpha * 100;
            
            statDist = bootstrp(nboot, bootfun, vect);
            
            ci(1,1) = prctile(statDist, a/2);
            ci(2,1) = prctile(statDist, 100-a/2);
            
        end
        
        function val = Bound(val, valRange)
            %Bounds input values to specified range or allowed members
            %
            %   val = MMath.Bound(val, valRange)
            %   
            % Inputs:
            %   val         Numeric scalar, vector or array
            %   valRange    Either (1) a tuple of boundaries (e.g. [ minVal, maxVal ])
            %               or (2) a numeric vector or array of all allowed values (number of elements must > 2) and
            %               each raw input value will be bound to the closest allowed value.
            % Output: 
            %   val         Same size as the input val with bound values
            
            if numel(valRange) > 2
                for i = 1 : numel(val)
                    dists = abs(valRange(:) - val(i));
                    [ ~, idx ] = min(dists);
                    val(i) = valRange(idx);
                end
            else
                val = max(val, min(valRange));
                val = min(val, max(valRange));
            end
        end
        
        function [ condDist, margDist ] = ConditionalDist(jointDist, givenWhich)
            %Compute conditional probability distribution from joint distribution
            %
            %   [ condDist, margDist ] = MMath.ConditionalDist(jointDist, givenWhich)
            %   
            % Inputs:
            %   jointDist       multidimentional (>=2) array of joint probability
            %   givenWhich      dimensions to condition on (currently has to be ndims(jointDist)-1 dimensions)
            % Output: 
            %   condDist        array of conditional distribution
            %   margDist        marginal distribution
            
            % Collapsing other dimensions
            numDims = ndims(jointDist);
            margWhich = setdiff(1:numDims, givenWhich);
            if isempty(margWhich)
                margDist = jointDist;
            else
                for i = 1 : length(margWhich)
                    margDist = nansum(jointDist, margWhich(i));
                end
            end
            
            % Normalization
            margSize = ones(1, numDims);
            margSize(1:ndims(margDist)) = size(margDist);
            condDist = jointDist ./ repmat(margDist, size(jointDist)./margSize);
            
            % Set NaN to zero
            condDist(isnan(condDist)) = 0;
        end
        
        function H = Entropy(probDist)
            %Calculates the Shannon's entropy of a given probability distribution
            %
            %   H = MMath.Entropy(probDist)
            %   
            % Inputs:
            %   probDist    A vector of probability values
            % Output: 
            %   H           Entropy in bits
            
            H = -nansum(probDist(:) .* log2(probDist(:)));
        end
        
        function expect = Expectation(distMat, val, idxDim)
            %Calculate expected values in the dimension of interest given other variables (assuming gaussian dist.)
            %
            %   expect = MMath.Expectation(distMat, val, idxDim)
            % 
            % Inputs:
            %   distMat     Joint probability distribution
            %   val         Values of each probabilities in the dimension of interest
            %   idxDim      Index of the dimension of interest
            % Output:
            %   expect      Expected values
            
            if nargin < 3
                idxDim = 1;
            end
            
            sizeDist = size(distMat);
            reshapeVect = ones(1, length(sizeDist));
            reshapeVect(idxDim) = length(val);
            val = reshape(val, reshapeVect);
            
            sizeDist(idxDim) = 1;
            expect = nansum(distMat .* repmat(val, sizeDist), idxDim);
        end
        
        function roiInd = Ind2Roi(ind, winRoi, valRange)
            %Converts each index to indices for indexing a corresponding region of interest (ROI)
            %e.g. indices [ 23; 56 ] with a window of [ -1 0 1 2 ] => ROIs of [ 22 23 24 25; 55 56 57 58 ]
            %
            %   roiInd = MMath.Ind2Roi(ind, winRoi, valRange)
            %   
            % Inputs:
            %   ind         An index or a vector of indices
            %   winRoi      A vector of relative indices (not a boundary tuple) indicating the region of interest
            %   valRange    Usually (1) a tuple of indexing boundaries (e.g. [ minIdx, maxIdx ])
            %               or (2) a numeric vector or array of all allowed index values (number of elements must > 2) and
            %               each index will be bound to the closest allowed value.
            % Output: 
            %   roiInd      An array where each row is a set of ROI indices for one input index
            %               ROIs causing edge issue are removed from the reuslt.
            
            if islogical(ind) || ~isempty(find(ind == 0, 1))
                if nargin < 3
                    valRange = [ 1 length(ind) ];
                end
                ind = find(ind);
            end
            
            roiInd = zeros(length(ind), length(winRoi));
            for i = 1 : length(winRoi)
                roiInd(:,i) = ind + winRoi(i);
            end
            
            roiInd = MMath.Bound(roiInd, valRange);
            
            validRoiMask = true(size(roiInd,1), 1);
            roiLength = size(roiInd, 2);
            for i = 1 : size(roiInd, 1)
                if unique(roiInd(i,:)) < roiLength
                    validRoiMask(i) = false;
                end
            end
            roiInd = roiInd(validRoiMask, :);
        end
        
        function mask = Ind2Logical(ind, vecLength)
            % Convert a vector of indices to logical mask
            % 
            %   mask = MMath.Ind2Logical(ind, vecLength)
            %   
            % Inputs:
            %   ind         A vector of indices
            %   vecLength   The length of the output vector
            % Output: 
            %   mask        A logical vector where elements at 'ind' are true
            
            if isrow(ind)
                mask = false(1, vecLength);
            else
                mask = false(vecLength, 1);
            end
            
            mask(ind) = true;
            
        end
        
        function [ data, maskNaN ] = InterpNaN(data)
            %Interpolates NaN values in the data
            %
            %   [ data, maskNaN ] = MMath.InterpNaN(data)
            %   
            % Inputs:
            %   data	    An array of column vector(s)
            % Output: 
            %   data        An array of column vector(s) with NaN values interpolated
            %   maskNaN     The logical mask of NaN values in the original data array
            
            if isrow(data)
                data = data';
            end
            
            maskNaN = isnan(data);
            for i = 1 : size(data,2)
                % Check for at least two non-NaN elements
                if sum(maskNaN(:,i)) <= length(maskNaN(:,i)) - 2
                    % Make sure NaN value exists in data
                    if ~isempty(find(maskNaN(:,i),1))
                        indv = find(~maskNaN(:,i));
                        data(:,i) = interp1(indv, data(indv,i), (1:size(data,1))', 'linear', 'extrap');
                    end
                else
                    warning('Needs at least two non-NaN elements for interpolation! Returns original values.');
                end
            end
        end
        
        function [ jointDist, axisLabels, binCoor ] = JointDist(randVars, numBins, axisLabels)
            % Calculates the joint probability distribution of multiple random variables
            %
            %   [ jointDist, axisLabels, binInd ] = MMath.JointDist(randVars, numBins)
            %   
            % Inputs:
            %   randVars	   	Random variables in an array of column vectors. Each row is an observation. 
            %   numBins         The number(s) of bins for input random variables. Use NaN to indicate categorical 
            %                   variable. You may assign different bin numbers to different variables in a
            %                   vector otherwise they all use the same bin number. 
            %   axisLabels      For categorical variables, you can provide predefined categories (e.g. to account
            %                   for unobserved values). It expects a 1-by-n cell array where n is the number of 
            %                   variables in randVars. Each element in this cell array is a vector of numeric 
            %                   categories along that dimension. 
            % Output: 
            %   jointDist       N-dimensional matrix of joint probability. The order of dimensions is the same
            %                   as the order of input variables.
            %   axisLabels      Labels of each axis in cell array.
            %   binCoor         Each row is a coordinate in the joint distribution sapce for the corresponding 
            %                   observation (row) in randVars. 
            
            % Handles user inputs
            if nargin < 3
                axisLabels = cell(1, size(randVars,2));
            end
            
            if length(numBins) ~= size(randVars,2)
                numBins = repmat(numBins(1), 1, size(randVars,2));
            end
            
            % Bins variables
            binCoor = zeros(size(randVars));
            for i = size(randVars,2) : -1 : 1
                if isnan(numBins(i))
                    % Catagorical
                    axisLabels{i} = union(axisLabels{i}, unique(randVars(:,i)));
                    binCoor(:,i) = arrayfun(@(x) find(axisLabels{i} == x), randVars(:,i));
                    numBins(i) = length(axisLabels{i});
                else
                    % Continuous
                    edges = linspace(nanmin(randVars(:,i)), nanmax(randVars(:,i)), numBins(i)+1);
                    axisLabels{i} = mean([ edges(1:end-1); edges(2:end) ])';
                    edges(end) = edges(end) + 1;
                    [ ~, ~, binCoor(:,i) ] = histcounts(randVars(:,i), edges);
                end
            end
            
            % Multidimensional tally
            dimInputStr = 'ndgrid(';
            for i = 1 : length(numBins)
                dimInputStr = [ dimInputStr, '1:numBins(', num2str(i), '), ' ];
            end
            dimInputStr = [ dimInputStr(1:end-2), ')' ];
            
            dimOutput = cell(1, length(numBins));
            [ dimOutput{:} ] = eval(dimInputStr);
            dimOutput = cell2mat(cellfun(@(x) x(:), dimOutput, 'UniformOutput', false));
            
            jointDist = zeros(numBins(:)');
            for i = size(dimOutput,1) : -1 : 1
                subBinCoor = binCoor;
                for j = 1 : length(numBins)
                    hitVect = subBinCoor(:,j) == dimOutput(i,j);
                    subBinCoor = subBinCoor(hitVect, :);
                end
                jointDist(i) = sum(hitVect);
            end
            
            jointDist = jointDist / size(randVars,1);
        end
        
        function boundariesInd = Logical2Boundaries(vect)
            %Converts logical(boolean/binary) vector to tuples indicating the bondaries of 1 regions
            %e.g. [ 0 0 0 1 1 1 0 0 1 ] => bondaries [ 4 6; 9 9 ]
            %
            %   bondariesInd = Logical2Bondaries(vect)
            %   
            % Inputs:
            %   vect            A logical(boolean/binary) vector
            % Output: 
            %   bondariesInd    Tuples (each row) indicating the bondaries of 1 regions
            
            if isvector(vect)
                vect = vect(:);
            end
            
            vect = [ zeros(1,size(vect,2)); vect; zeros(1,size(vect,2)) ];
            dVect = diff(vect);
            boundariesInd = [ find(dVect == 1), find(dVect == -1) - 1 ];
        end
        
        function I = MutualInfo(jointDist)
            %Calculates the mutual information of two random variables from their joint probability distribution
            %
            %   I = MMath.MutualInfo(jointDist)
            %   
            % Inputs:
            %   jointDist   The joint probability distribution matrix of two random variables
            % Output: 
            %   I           Mutual information in bits
            
            marginDist{1} = nansum(jointDist, 2);
            marginDist{2} = nansum(jointDist, 1);
            [ marginDist{2}, marginDist{1} ] = meshgrid(marginDist{2}, marginDist{1});
            I = jointDist .* log2(jointDist ./ (marginDist{1}.*marginDist{2}));
            I = nansum(I(:));
        end
        
        function [corrVal, pVal] = NanCorr(x, y)
            % Similar to MATLAB built-in function corr but handles NaN values
            
            x = x(:);
            y = y(:);
            indNan = isnan(x) | isnan(y);
            [corrVal, pVal] = corr(x(~indNan), y(~indNan));
        end
        
        function [ data, factors ] = Normalize(data, keepSign)
            %Normalizes column vectors so that the maximal value or amplitude is one
            %
            %   [ data, factors ] = MMath.Normalize(data)
            %   [ data, factors ] = MMath.Normalize(data, keepSign)
            %   
            % Inputs:
            %   data            Column vectors of data array
            %   keepSign        Whether to keep the original sign of the data, i.e. normalize the maximal
            %                   amplitude to one (rather than absolute value). (default is true)
            % Output: 
            %   data            Normalized data
            %   factors         Scaling factors used to normalize each column vectors. If the factor is zero,
            %                   eps, the minimal amount of value in MATLAB, is returned.
            
            % Handles user inputs
            if nargin < 2
                keepSign = true;
            end
            
            if isvector(data)
                data = data(:);
            end
            
            % Normalization
            [ ~, maxInd ] = max(abs(data), [], 1);
            
            if ~isempty(maxInd)
                for i = size(data,2) : -1 : 1
                    factors(i) = data(maxInd(i),i);
                    if factors(i) == 0
                        factors(i) = eps;
                    end
                    if keepSign
                        factors(i) = abs(factors(i));
                    end
                    data(:,i) = data(:,i) / factors(i);
                end
            end
        end
        
        function [ data, factor, offset ] = Normalize2(data)
            %Normalizes 2D array so that the maximal value or amplitude is
            %one and the minimal value is zero
            %
            %   [ data, factors ] = MMath.Normalize(data)
            %   [ data, factors ] = MMath.Normalize(data, keepSign)
            %   
            % Inputs:
            %   data            numeric array
            %   keepSign        Whether to keep the original sign of the data, i.e. normalize the maximal
            %                   amplitude to one (rather than absolute value). (default is true)
            % Output: 
            %   data            Normalized data
            %   factors         Scaling factors used to normalize each column vectors. If the factor is zero,
            %                   eps, the minimal amount of value in MATLAB, is returned.
            
            maxVal = nanmax(data(:));
            minVal = nanmin(data(:));
            
            factor = maxVal - minVal;
            offset = - minVal;
            
            data = (data + offset) / factor;
        end
        
        function [ vect, indKept, lims ] = RemoveOutliers(varargin)
            %Removes outliers
            %
            %   [ vect, indKept, lims ] = MMath.RemoveOutliers(vect)
            %   [ vect, indKept, lims ] = MMath.RemoveOutliers(vect, boundParam)
            %   [ vect, indKept, lims ] = MMath.RemoveOutliers(vect, boundParam, method)
            %
            % Inputs:
            %   vect            A vector of numeric data
            %   boundParam      Either (1) a positive scaler of the number of deviation or (2) a tuple specifying the 
            %                   numbers of deviation on each side respectively (e.g. [ numLower, numUpper ]).
            %                   The default for standard deviation is [ 3 3 ], for whisker is [ 1.5 1.5 ], for
            %                   percentile is [ 0.1 0.1 ].
            %   method          'std' for removal based on the number of standard deviation (default); 
            %                   'whisker' based on the number of difference of 25 to 75 percentile value (same 
            %                   convention as MATLAB's built-in whisker plot);
            %                   'percentile' removes the specified lower and upper percentage of data; 
            %                   'cut' uses actual cutoff thresholds to remove outliers.
            % Output: 
            %   vect            The vector without outliers
            %   indKept         The binary indices of values being kept
            %   lims            A tuple containing values of lower and upper limit used for removal
            
            % Handles user inputs
            p = inputParser();
            p.addRequired('vect', @isnumeric);
            p.addOptional('numDev', [], @(x) isnumeric(x) && numel(x) <= 2);
            p.addOptional('method', 'std', @(x) any(strcmpi(x, {'std', 'whisker', 'percentile', 'cut'})));
            p.parse(varargin{:});
            vect = p.Results.vect(:);
            boundParam = p.Results.numDev;
            method = lower(p.Results.method);
            
            if isempty(boundParam)
                switch method
                    case 'std'
                        boundParam = 3;
                    case 'whisker'
                        boundParam = 1.5;
                    case 'cut'
                        error('Must provide cutoff limits');
                    case 'prctile'
                        boundParam = .1;
                end
            end
            
            if numel(boundParam) == 1
                boundParam = [ boundParam, boundParam ];
            end
            
            % Outlier removal
            if ~any(isnan(boundParam))
                switch method
                    case 'std'
                        m = nanmean(vect);
                        s = nanstd(vect);
                        lims = [ m - boundParam(1)*s, m + boundParam(2)*s ];
                    case 'whisker'
                        q1 = prctile(vect, 25);
                        q3 = prctile(vect, 75);
                        lims = [ q1 - boundParam(1)*(q3-q1), q3 + boundParam(2)*(q3-q1) ];
                    case 'cut'
                        lims = sort(boundParam);
                    case 'percentile'
                        lims = [ prctile(vect, boundParam(1)), prctile(vect, 100-boundParam(2)) ];
                end
                indKept = vect >= lims(1) & vect <= lims(2);
                vect = vect(indKept);
            else
                lims = [ -inf, inf ];
                indKept = true(size(vect));
            end
        end
        
        function y = SigMf(x, params)
            %SIGMF Sigmoid curve membership function.
            %   SIGMF(X, PARAMS) returns a matrix which is the sigmoid
            %   membership function evaluated at X. PARAMS is a 2-element vector
            %   that determines the shape and position of this membership function.
            %   Specifically, the formula for this membership function is:
            %
            %   SIGMF(X, [A, C]) = 1./(1 + EXP(-A*(X-C)))
            %
            %   For example:
            %
            %       x = (0:0.2:10)';
            %       y1 = sigmf(x, [-1 5]);
            %       y2 = sigmf(x, [-3 5]);
            %       y3 = sigmf(x, [4 5]);
            %       y4 = sigmf(x, [8 5]);
            %       subplot(211); plot(x, [y1 y2 y3 y4]);
            %       y1 = sigmf(x, [5 2]);
            %       y2 = sigmf(x, [5 4]);
            %       y3 = sigmf(x, [5 6]);
            %       y4 = sigmf(x, [5 8]);
            %       subplot(212); plot(x, [y1 y2 y3 y4]);
            %       set(gcf, 'name', 'sigmf', 'numbertitle', 'off');
            %
            %   See also DSIGMF, EVALMF, GAUSS2MF, GAUSSMF, GBELLMF, MF2MF, PIMF, PSIGMF, SMF,
            %   TRAPMF, TRIMF, ZMF.
            
            %       Roger Jang, 6-29-93, 4-17-93.
            %   Copyright 1994-2002 The MathWorks, Inc.
            
            if nargin ~= 2
                error('Two arguments are required by the sigmoidal MF.');
            elseif length(params) < 2
                error('The sigmoidal MF needs at least two parameters.');
            end
            
            a = params(1); c = params(2);
            y = 1./(1 + exp(-a*(x-c)));
        end
        
        function [ stErr, stDev ] = StandardError(data, dim)
            %Calculates the standard error of the population mean
            %
            %   [ stErr, stDev ] = MMath.StandardError(data)
            %   [ stErr, stDev ] = MMath.StandardError(data, dim)
            %   
            % Inputs:
            %   data	    An array of column vector(s)
            % Output: 
            %   stErr       Standard error of the population mean
            %   stDev       Standard deviation of the population
            
            if nargin < 2
                dim = 1;
            end
            
            if isvector(data)
                data = data(:);
            end
            
            stDev = nanstd(data, 0, dim);
            stErr = stDev / sqrt(size(data,dim));
        end
    end
end

