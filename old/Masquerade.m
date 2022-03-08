classdef Masquerade < handle
    %MASQUERADE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        movie = [];
        objMasks = {};
        ptMasks = [];
        currentOffset = [];
    end
    
    methods
        % Constructor (a movie is the least input for doing anything)
        function this = Masquerade(mov)
            this.movie = mov;
        end
        
        % Making masks for the entire movie
        function Dance(this, measurement, numPoints, pxPadding, pxOffset, faceSideInImage)
            
            % Preallocating memory
            [ imgHeight, imgWidth, imgFrames ] = size(this.movie);
            if strcmp(faceSideInImage, 'top')
                halfImgRows = 1 : round(imgHeight/2);
                pxOffsetSign = 1;
            elseif strcmp(faceSideInImage, 'bottom')
                halfImgRows = round(imgHeight/2) + 1 : imgHeight;
                pxOffsetSign = -1;
            end
            this.objMasks = cell(imgFrames, 1);
            for i = 1 : imgFrames
                this.objMasks{i} = this.MakeOneMask(this.movie(halfImgRows,:,i), pxOffset, faceSideInImage);
            end
            
            % Convert object masks to point masks
            if nargin > 1
                if nargin < 5
                    pxOffset = 8;
                end
                if nargin < 4
                    pxPadding = 60;
                end
                if nargin < 3
                    numPoints = 10;
                end
                this.currentOffset = pxOffset;
                pxOffset = pxOffset*pxOffsetSign;
                this.MakePointMasks(measurement, numPoints, pxPadding, pxOffset, faceSideInImage);
                this.ptMasks = Masquerade.Offset(this.ptMasks, pxOffset, pxOffset, faceSideInImage);
%                 this.ptMasks = repmat(this.ptMasks(1,:,:),2500,1,1);
            end
        end
        
        % Save numeric(points) masks
        function SaveMasks(this, path)
            data_faceMasks = this.ptMasks;
            currentOffset = this.currentOffset;
            save(path, 'data_faceMasks', 'currentOffset');
        end
        
        % Load numeric masks from file (for inspection or making demo)
        function LoadMasks(this, path)
            load(path, '-mat');
            this.ptMasks = data_faceMasks;
        end
        
        % Save movie with masks on
        function MakeAVI(this, path)
            if nargin < 2
                path = 'masquerade';
            end
            
            vidObj = VideoWriter(path);
            vidObj.FrameRate = 50;
            open(vidObj);
            
            figure;
            axes('Parent', gcf, 'Units', 'pixels', 'Position', [ 0 1 640 480 ]);
            
            hold on
            ih = imagesc(this.movie(:,:,1), [0 255]);
            colormap gray
            
            ch = plot(this.ptMasks(1,:,1), this.ptMasks(1,:,2), 'r', 'LineWidth', 2);
            axis ij off
            xlim([1 size(this.movie,2)]);
            ylim([1 size(this.movie,1)]);
            hold off
            
            for i = 1 : size(this.ptMasks, 1)
                set(ih, 'CData', this.movie(:,:,i));
                set(ch, 'XData', this.ptMasks(i,:,1));
                set(ch, 'YData', this.ptMasks(i,:,2));
                drawnow;
                
                frameObj = getframe;
                writeVideo(vidObj, frameObj.cdata);
            end

            close(vidObj);
        end
        
        % Save movie with masks on
        function mwm = MakeTIFF(this)
            mwm = zeros(size(this.movie), 'uint8');
            
            figure;
            axes('Parent', gcf, 'Units', 'pixels', 'Position', [ 0 1 640 480 ]);
            
            hold on
            ih = imagesc(this.movie(:,:,1), [ 0 255 ]);
            colormap gray
            
            ch = plot(this.ptMasks(1,:,1), this.ptMasks(1,:,2), 'k', 'LineWidth', 2);
            axis ij off
            xlim([1 size(this.movie,2)]);
            ylim([1 size(this.movie,1)]);
            hold off
            
            for i = 1 : size(this.ptMasks, 1)
                set(ih, 'CData', this.movie(:,:,i));
                set(ch, 'XData', this.ptMasks(i,:,1));
                set(ch, 'YData', this.ptMasks(i,:,2));
                drawnow;
                
                frameObj = getframe;
                mwm(:,:,i) = frameObj.cdata(:,:,1);
            end
            
            Img23.Export('masquerade', mwm);
        end
        
        % Plot a frame with mask
        function ShowResult(this, idx)
            figure
            imagesc(this.movie(:,:,idx), [ 0 255 ]);
            colormap gray
            hold on
            
            Masquerade.PlotMask(this.ptMasks(idx,:,:));
            axis ij
            xlim([ 1, size(this.movie,2) ]);
            ylim([ 1, size(this.movie,1) ]);
            hold off
        end
    end
    
    
    
    methods(Access = private)
        function smoothSplineFit = MakeOneMask(~, img, pxOffset, faceSideInImage)
            % Make a mask for one frame
            
            % Parameters which will be used again and again
            persistent se threshFunc fitParam;
            if isempty(se)
%                 se = strel('rectangle', [ 1 10 ]);
                se = strel('arbitrary', eye(1));
            end
            if isempty(threshFunc)
%                 threshFunc = @(x) -480/640 * x + 240;
                threshFunc = @(x) 0 * x + 1;
            end
            if isempty(fitParam)
                fitParam.ft = fittype( 'smoothingspline' );
                fitParam.opts = fitoptions( 'Method', 'SmoothingSpline' );
                fitParam.opts.SmoothingParam = 1e-05;
            end
                
            % Normalize and smooth
            [imgHeight, imgWidth] = size(img);
            imgNorm = imadjust(img);
            imgBlur = imgaussfilt(imgNorm, 10);
            bwThresh = 1-single(median(median(imgBlur)))/255;

            % convert to binary image
            bwDiff = imbinarize(imgBlur, bwThresh);

            % remove small connected objects (e.g. pole)
            bwDiff2 = ~bwareaopen(~bwDiff, 1000);
            
            if strcmp(faceSideInImage, 'top')
                % resize from ~middle of face          
                resizeFactor = (imgHeight + 20)/imgHeight;
                eroDiffResize = imresize(bwDiff2, resizeFactor);
                [~, scaleWidth] = size(eroDiffResize);
                faceRangeX = [find(sum(1-eroDiffResize)>0,1,'first') ...
                    find(sum(1-eroDiffResize)>0,1,'last')];
                imgEnd = min([ceil(mean(faceRangeX))+scaleWidth/2 scaleWidth]);
                eroDiffResize = eroDiffResize(1:imgHeight, ...
                    imgEnd-imgWidth+1 : imgEnd);
            elseif strcmp(faceSideInImage, 'bottom')
                % resize from ~middle of face
                resizeFactor = (imgHeight + 10)/imgHeight;
                eroDiffResize = imresize(bwDiff2, resizeFactor);
                [~, scaleWidth] = size(eroDiffResize);
                faceRangeX = [find(sum(1-eroDiffResize)>0,1,'first') ...
                    find(sum(1-eroDiffResize)>0,1,'last')];
                imgEnd = min([ceil(mean(faceRangeX))+scaleWidth/2 scaleWidth]);
                resizeHeight = size(eroDiffResize,1);
                eroDiffResize = eroDiffResize(resizeHeight-imgHeight:resizeHeight, ...
                    imgEnd-imgWidth+1 : imgEnd);
%                 eroDiffResize = bwDiff2;
%                 eroDiffResize = eroDiffResize(1:imgHeight, 1 : imgWidth);
            end

            % Take spatial derivative to find boundary
            [~,FY] = gradient(eroDiffResize);
                
%             figure(1); imshow(imgNorm);
%             figure(2); imshow(imgBlur);
%             figure(3); imshow(bwDiff);
%             figure(33); imshow(bwDiff2);
%             figure(4); imshow(eroDiffResize);
%             figure(5); imshow(FY);

            % Contour Fitting
            
            % Take Every Pixel in the Lower One-Third as Candidate Contour Points
            [ Y, X ] = find(FY);
            
%             figure(6); axis ij equal; imshow(bwDiff); hold on; plot(X,Y, 'r', 'LineWidth', 2); hold off
            
%             figure(44)
%             scatter(X, Y, 'k.');
%             axis ij equal
%             xlim([ 1 imgWidth ]);
%             ylim([ 1 imgHeight ]);
            
            % Gross Linear Fit to Eliminate Outliers (e.g. pole)
            outInd = threshFunc(X) - Y > 0;
            X(outInd) = [ ];
            Y(outInd) = [ ];
            
%             hold on
%             plot(threshFunc(1:imgWidth));
%             scatter(X, Y, 'r.');
%             hold off
            
            % Fitting of Face Contour
            smoothSplineFit = fit(X, Y, fitParam.ft, fitParam.opts);
            
%             hold on
%             plot(smoothSplineFit(1:imgWidth));
%             hold off
            
%             figure(7); axis ij equal; imshow(imgNorm); hold on; plot(X,Y, 'r', 'LineWidth', 2); plot(smoothSplineFit(1:imgWidth)); hold off

        end
        
        function MakePointMasks(this, measurements, numPoints, pxPadding, pxOffset, faceSideInImage)
            % Use info from .measurements file to find follicle boundaries
            % and convert Fit Object to series of points (#frame * #points/mask * 2 (for x & y))
            
            if strcmp(faceSideInImage, 'bottom')
                pxOffsetSign = -1;
                pxOffsetY = size(this.movie,1)/2;
                pxOffsetX = 20;
            else
                pxOffsetY = 20;
                pxOffsetX = 20;
            end
            
            entryNum = length(measurements);
            entryIdx = 1;
            this.ptMasks = zeros(length(this.objMasks), numPoints, 2);
            for i = 1:length(this.objMasks)
                minX = inf;
                maxX = 0;
                while measurements(entryIdx).fid == i-1
                    if measurements(entryIdx).label ~= -1
                        minX = min(minX, measurements(entryIdx).follicle_x);
                        maxX = max(maxX, measurements(entryIdx).follicle_x);
                    end
                    if entryIdx < entryNum
                        entryIdx = entryIdx + 1;
                    else
                        break;
                    end
                end
                minX = minX - pxPadding;
                maxX = maxX + pxPadding;
%                 maxX = 640;
                minX = MMath.Bound(minX, [1 640]);
                maxX = MMath.Bound(maxX, [1 640]);
                
                this.ptMasks(i,:,1) = linspace(minX, maxX, numPoints);
                % find y of cfit for x-coordinates
                this.ptMasks(i,:,2) = this.objMasks{i}(this.ptMasks(i,:,1));
                this.ptMasks(i,:,2) = MMath.Bound(this.ptMasks(i,:,2), [1 480]);
            end 
            
            vx = this.ptMasks(:,:,1);
            vy = this.ptMasks(:,:,2);
%                  
            vx = vx + pxOffset/2 + pxOffsetX;      
            vy = vy + pxOffset + pxOffsetY;      
%             
            this.ptMasks(:,:,1) = vx;
            this.ptMasks(:,:,2) = vy;
        end
        
    end
    
    
    
    methods(Static)
        function PlotMask(facemasks, plotString, lineWidth)
            if nargin < 3
                lineWidth = 2;
            end
            if nargin < 2
                plotString = 'r';
            end
            plot(facemasks(1,:,1), facemasks(1,:,2), plotString, 'LineWidth', lineWidth);
        end
        
        function PlotRainbowMasks(facemasks, interv, numColors)
            if nargin < 3
                numColors = 10;
            end
            if nargin < 2
                interv = 2;
            end
            
            indRange = 1 : interv : size(facemasks,1);
            modNum = mod(length(indRange), numColors);
            indRange = indRange(1:end-modNum);
            indRange = reshape(indRange, length(indRange)/numColors, numColors);
            
            rainbowCode = MPlot.ColorCodeRainbow(numColors);
            hold on
            for i = 1 : size(indRange, 2)
                plot(facemasks(indRange(:,i),:,1)', facemasks(indRange(:,i),:,2)', 'Color', rainbowCode(i,:));
            end
        end
        
        function PlotMaskProfile(facemasks, plotString, ptRange)
            if nargin < 3
                ptRange = 1 : size(facemasks,2);
            end
            if nargin < 2
                plotString = 'b';
            end
            plot(facemasks(:, ptRange, 1), plotString);
            hold on;
            plot(facemasks(:, ptRange, 2) + 100, plotString);
        end
        
        function fm = Offset(fm, offset0, offset1,faceSideInImage)
            
                vx = fm(:,:,1) - 320;
                vy = fm(:,:,2);

    %             k = (max(vy,[],2) - offset0 + offset1) ./ max(vy,[],2);
    %             k = repmat(k, size(vx)./size(k));
    %             k = 1;

                fm(:,:,1) = vx  - offset0/2 + offset1/2 + 320;
                fm(:,:,2) = vy - offset0 + offset1;
                
        end
        
        function fm = Filter(fm)
            % Parameters for x and y prior radii (in pixels) respectively
            r = [ 20 10 ];
            
            % Filters frame by frame
            for i = 2 : size(fm,1)
                % Filters x and y respectively
                for d = 1:2
                    hypo = fm(i-1,:,d);                      % hypothesized value
                    obser = fm(i,:,d);                       % observed value
                    k = min(abs(hypo - obser), r(d)*0.98) / r(d);   % the weight of hypothesis
                    poster = k.*(hypo) + (1-k).*obser;
                    if d == 1
                        poster = sort(poster);
                    end
                    fm(i,:,d) = poster;
                end
            end
        end
    end
    
end

