classdef WhiskerLinker < handle
    %WHISKERLINKER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        measurements;
        cleanMeasurements;
        outMeasurements;
        
        maxJitter = 40;
        maxOverlap = 2;
        
        detectedWhiskerIDs;
        missingTable;
        follicleXY;
        follicleJitter;
    end
    
    methods
        % Constructor
        function this = WhiskerLinker(measurements)
            
            % Load measurements struct array
            if ischar(measurements)
                measurements = Whisker.LoadMeasurements(measurements);
            end
            this.measurements = measurements;
            
            
            % Sorts the measurements struct by fid (in case of zero-fid ending or any irregular frame order)
            [~, order] = sort([measurements.fid]);
            this.outMeasurements = measurements(order);
            
            numFrame = this.outMeasurements(end).fid + 1;
            numEntry = length(this.outMeasurements);
            for i = 1 : numEntry
                this.outMeasurements(i).label = -1;
            end
            
            
            % Excludes unqualified trajectories based on length and follicle position
            blacklist = [ this.outMeasurements.length ] < 50 | ...
            [ this.outMeasurements.follicle_y ] < 380 | ...
            [ this.outMeasurements.follicle_x ] > 480 | ...
            [ this.outMeasurements.follicle_x ] < 170;
            
            % Resets all existing labels (meanwhile applies pre-exclusion)
            this.cleanMeasurements = this.outMeasurements(~blacklist);
            
            
            % Groups entries by frame
            entryIndByFrame = cell(numFrame, 1);
            currentEntry = 1;
            % Iterates through all 2500 frames
            for i = 0 : numFrame-1
                % Iterates through all entries belonging to this frame
                while this.outMeasurements(currentEntry).fid == i
                    % Registers the entry index if the trajectory is valid
                    if ~blacklist(currentEntry)
                        entryIndByFrame{i+1}(end+1) = currentEntry;
                    end
                    
                    % Increments index for next entry
                    if currentEntry < numEntry
                        currentEntry = currentEntry + 1;
                    else
                        break;
                    end
                end
                
                % Combine faulty overlapping segments (e.g. KS0167A_Num460 frame 1206)
                follicleX = [ this.outMeasurements(entryIndByFrame{i+1}).follicle_x ]';
                follicleY = [ this.outMeasurements(entryIndByFrame{i+1}).follicle_y ]';
                if ~isempty(follicleX)
                    segment2del = this.FindOverlap([ follicleX, follicleY ]);
                    entryIndByFrame{i+1}(segment2del) = [ ];
                end
            end
            
            % Determines the number of whiskers
            numWhiskers = cellfun(@length, entryIndByFrame);
            seedFrameIdx = find(numWhiskers == median(numWhiskers), 1);
            
            % Forward linking
            for i = seedFrameIdx : length(entryIndByFrame)
                if ~isempty(entryIndByFrame{i})
                    % Initialize info matrix of the current frame
                    newPosInfo = zeros(length(entryIndByFrame{i}), 5);
                    newPosInfo(:,2) = 1;                                                            % mask
                    newPosInfo(:,3) = entryIndByFrame{i}';                                          % entry indices
                    newPosInfo(:,4) = [ this.outMeasurements(entryIndByFrame{i}).follicle_x ]';     % follicle x
                    newPosInfo(:,5) = [ this.outMeasurements(entryIndByFrame{i}).follicle_y ]';     % follicle y
                    
                    % Identify the same whiskers
                    if i == seedFrameIdx
                        % Find the number of whiskers (from frame #0) for preallocating space
                        posInfo = zeros([ size(newPosInfo), length(entryIndByFrame) ]);
                        posInfo(:,:,i) = this.FindOrder(0, newPosInfo);
                    else
                        posInfo(:,:,i) = this.FindOrder(i, newPosInfo, posInfo(:,:,i-1));
                    end
                    
                    % Apply result into outMeasurements
                    for j = 1 : size(posInfo,1)
                        if posInfo(j,2,i) % When it is not masked by zeros
                            this.outMeasurements(posInfo(j,3,i)).label = posInfo(j,1,i);
                        end
                    end
                end
            end
            
            % Backward linking
            for i = seedFrameIdx-1 : -1 : 1
                if ~isempty(entryIndByFrame{i})
                    % Initialize info matrix of the current frame
                    newPosInfo = zeros(length(entryIndByFrame{i}), 5);
                    newPosInfo(:,2) = 1;                                                            % mask
                    newPosInfo(:,3) = entryIndByFrame{i}';                                          % entry indices
                    newPosInfo(:,4) = [ this.outMeasurements(entryIndByFrame{i}).follicle_x ]';     % follicle x
                    newPosInfo(:,5) = [ this.outMeasurements(entryIndByFrame{i}).follicle_y ]';     % follicle y
                    
                    % Identify the same whiskers
                    posInfo(:,:,i) = this.FindOrder(i, newPosInfo, posInfo(:,:,i+1));
                    
                    % Apply result into outMeasurements
                    for j = 1 : size(posInfo,1)
                        if posInfo(j,2,i) % When it is not masked by zeros
                            this.outMeasurements(posInfo(j,3,i)).label = posInfo(j,1,i);
                        end
                    end
                end
            end
            
            
            % Generate Reports
            numLabel = max([ this.outMeasurements.label ]) + 1;
            this.detectedWhiskerIDs = 0 : numLabel-1;
            this.follicleXY = NaN(numFrame, numLabel, 2);   % x,y positions of all follicles of all time
            for i = 1 : numEntry    % filling in informations
                if this.outMeasurements(i).label ~= -1
                    this.follicleXY(this.outMeasurements(i).fid + 1, this.outMeasurements(i).label + 1, :) = ...
                        [ this.outMeasurements(i).follicle_x, this.outMeasurements(i).follicle_y ];
                end
            end
            
            [ missingFrame, missingLabel ] = find(isnan(this.follicleXY(:,:,1)));   % find missing detection
            missingFrame = missingFrame - 1;    % make zero-based
            missingLabel = missingLabel - 1;    % make zero-based
            
            this.follicleJitter = diff(this.follicleXY);    % calculate the jittering of follicle positions
            this.follicleJitter = sqrt(this.follicleJitter(:,:,1).^2 + this.follicleJitter(:,:,2).^2);  % convert to 2D distance
            
            [ ~, order ] = sort(missingFrame);  % Organize result in the order of frames
            this.missingTable = table(missingFrame(order), missingLabel(order), 'VariableNames',{ 'FrameID', 'WhiskerID' });
            this.follicleJitter = this.follicleJitter;
        end
        
        
        function [ lastLinkedInfo, missingList, sqDist ] = FindOrder(this, fid, newRawInfo, lastLinkedInfo)
            if fid == 0
                % Find the order of whiskers from right(large follicle_x) to left(small follicle_x)
                [ ~, order ] = sort(newRawInfo(:,4), 'descend');
                % Label n whiskers from 0 to n-1
                newRawInfo(:, 1) = 0 : size(newRawInfo, 1) - 1;
                % Set the mask of the first frame
                newRawInfo(:, 2) = 1;
                % Rearrange the Entry number, follicle_x & _y
                newRawInfo(:, 3:end) = newRawInfo(order, 3:end);
                % Output result
                lastLinkedInfo = newRawInfo;
            else
                % Initialize newLinkedInfo array as the lastLinkedInfo array
                newLinkedInfo = lastLinkedInfo;
                % Initialize mask with zeros, assuming none of them are valid
                newLinkedInfo(:,2) = 0;
                % Distance matrix between whiskers in last frame (lastLinkedInfo) and
                % candidates in the new frame (newRawInfo)
                sqDist = zeros(size(newRawInfo, 1), size(lastLinkedInfo, 1));
                for i = 1 : size(lastLinkedInfo, 1)
                    sqDist(:,i) = sqrt((lastLinkedInfo(i,4) - newRawInfo(:,4)).^2 + (lastLinkedInfo(i,5) - newRawInfo(:,5)).^2);
                end
                
                % Sort all distances below threshold and find their positions
                [ ~, distOrder ] = sort(sqDist(sqDist < this.maxJitter)); % The shorter, the more confidence that they are the same
                [ rOrder, cOrder ] = ind2sub(size(sqDist), find(sqDist < this.maxJitter));
                rOrder = rOrder(distOrder); % New whiskers
                cOrder = cOrder(distOrder); % Old whiskers
                % Store linked labels, here initialize with all -1
                linked = - ones(length(rOrder), 2);
                for i = 1 : length(rOrder)
                    if isempty(find(linked(:,1) == rOrder(i), 1)) && isempty(find(linked(:,2) == cOrder(i), 1))
                        linked(i,:) = [ rOrder(i) cOrder(i) ]; % Linked pairs will not be used for linking remaining whiskers
                        newLinkedInfo(cOrder(i), 2) = 1; % Mark this as a valid whisker
                        newLinkedInfo(cOrder(i), 3:end) = newRawInfo(rOrder(i), 3:end);
                    end
                end
                
                % Correct any potential violation of whisker label sequence
                [ ~, rightOrder ] = sort(newLinkedInfo(:,4), 'descend');
                newLinkedInfo(:,2:end) = newLinkedInfo(rightOrder, 2:end);
                lastLinkedInfo = newLinkedInfo;
            end
        end
        
        
        function member2del = FindOverlap(this, coordinates)
            member2del = [ ];
            
            x = coordinates(:,1);
            y = coordinates(:,2);
            numMember = length(x);
            
            crossDist = sqrt((repmat(x, 1, numMember) - repmat(x', numMember, 1)).^2 ...
                + (repmat(y, 1, numMember) - repmat(y', numMember, 1)).^2);
            
            [ rInd, cInd ] = ind2sub(size(crossDist), find(crossDist < this.maxOverlap)); % Find super short distances
            for j = 1 : length(rInd)
                if rInd(j) > cInd(j) % Off-diagnal super short distance means overlapping
                    member2del(end+1) = rInd(j); % Prepare to eliminate them
                end
            end
        end
        
        
        function Save(this, filePath)
            Whisker.SaveMeasurements(filePath, this.outMeasurements);
        end
        
        
        function SaveRaw(this, filePath)
            Whisker.SaveMeasurements(filePath, this.measurements);
        end
        
        
        
        
        
        % The following methods are for displaying intermediate or final results
        function PlotRawFollicles(this)
            figure;
            scatter([this.measurements.follicle_x], [this.measurements.length]);
            figure;
            scatter([this.measurements.follicle_x], [this.measurements.follicle_y]);
            axis ij;
            figure;
            scatter3([this.measurements.follicle_x], [this.measurements.follicle_y], [this.measurements.length]);
        end
        
        
        function PlotCleanFollicles(this)
            figure
            scatter([this.cleanMeasurements.follicle_x], [this.cleanMeasurements.length]);
            figure
            scatter3([this.cleanMeasurements.follicle_x], [this.cleanMeasurements.follicle_y], [this.cleanMeasurements.length]);
        end
        
        
        function PlotReport(this, wid)
            if nargin < 2
                wid = 1:size(this.follicleJitter,2);
            else
                wid = wid + 1;
            end
            figure
            hold on;
            for i = 0 : max(this.missingTable.WhiskerID)
                ind = find(this.missingTable.WhiskerID == i);
                stem(this.missingTable.FrameID(ind), ones(size(this.missingTable.FrameID(ind))) * max(this.follicleJitter(:)), '--');
            end
            plot(this.follicleJitter(:,wid));
            hold off;
            grid minor, pan xon, zoom xon;
            ylabel('pixel');
            xlabel('frame');
        end
        
    end
    
end

