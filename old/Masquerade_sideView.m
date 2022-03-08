classdef Masquerade_sideView < handle
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
        function this = Masquerade_sideView(mov)
            this.movie = mov;
        end
        
        % Making masks for the entire movie
        function Dance(this, measurement, numPoints, pxPadding, pxOffset)
            % Preallocating memory
            [ imgHeight, imgWidth, imgFrames ] = size(this.movie);
%             halfImgRows = 1 : imgHeight;
            halfImgRows = 1 : imgHeight;
            this.objMasks = cell(imgFrames, 1);
            for i = 1 : imgFrames
                this.objMasks{i} = this.MakeOneMask(this.movie(halfImgRows,:,i));
            end
            
            % Convert object masks to point masks
            if nargin > 1
                if nargin < 5
                    pxOffset = 8;
                end
                if nargin < 4
                    pxPadding = 100;
                end
                if nargin < 3
                    numPoints = 10;
                end
                this.MakePointMasks(measurement, numPoints, pxPadding, pxOffset);
                this.ptMasks = Masquerade_sideView.Offset(this.ptMasks, 0, pxOffset);
                
                %static mask
%                 this.ptMasks = repmat(this.ptMasks(1,:,:),2500,1,1);
                this.currentOffset = pxOffset;
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
            [ imgHeight, imgWidth, ~ ] = size(this.movie);
            if nargin < 2
                path = 'masquerade';
            end
            
            vidObj = VideoWriter(path);
            vidObj.FrameRate = 50;
            open(vidObj);
            
            figure;
            axes('Parent', gcf, 'Units', 'pixels', 'Position', [ 0 1 imgWidth imgHeight ]);
            
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
            [ imgHeight, imgWidth, ~ ] = size(this.movie);
            mwm = zeros(size(this.movie), 'uint8');
            
            figure;
            axes('Parent', gcf, 'Units', 'pixels', 'Position', [ 0 1 imgWidth imgHeight ]);
            
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
            
            Masquerade_sideView.PlotMask(this.ptMasks(idx,:,:));
            axis ij
            xlim([ 1, size(this.movie,2) ]);
            ylim([ 1, size(this.movie,1) ]);
            hold off
        end
    end
    
    
    
    methods(Access = private)
        function smoothSplineFit = MakeOneMask(~, img)
            % Make a mask for one frame
            
            % Parameters which will be used again and again
            persistent se threshFunc fitParam;
            if isempty(se)
                se = strel('rectangle', [ 1 10 ]);
            end
            if isempty(threshFunc)
                threshFunc = @(x) 0 * x + 1;
            end
            if isempty(fitParam)
                fitParam.ft = fittype( 'smoothingspline' );
                fitParam.opts = fitoptions( 'Method', 'SmoothingSpline' );
                fitParam.opts.SmoothingParam = 1e-05;
            end
            
            % Image Scaling & Subtraction
            
            % Scale Up Grayscale Image
            imgScaled = imresize(img, 1.2);
            
            % Cut Scaled Image to Fit with Original Frame
            [ imgHeight, imgWidth ] = size(img);
            [ ~, scWidth ] = size(imgScaled);
            xBegin = (scWidth - imgWidth)/2 + 1;
            xEnd = xBegin + imgWidth - 1;
            imgScaled = imgScaled(end - imgHeight + 1 : end, xBegin : xEnd);
            
            % Image Subtraction
            imgDiff = img - imgScaled;
            
            % Convert to Binary Image
            bwDiff = im2bw(imadjust(imgDiff), 0.2);
            
            % Erode Vertical Features
            eroDiff = imerode(bwDiff, se);
            
%             figure(1); imshow(imgDiff);
%             figure(2); imshow(bwDiff);
%             figure(3); imshow(eroDiff);
            
            
            % Contour Fitting
            
            % Take Every Pixel in the Lower One-Third as Candidate Contour Points
            [ Y, X ] = find(eroDiff);
            
%             figure(4)
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
%             plot(smoothSplineFit(1:imgWidth) - imgHeight, 'r');
%             hold off
        end
        
        function MakePointMasks(this, measurements, numPoints, pxPadding, pxOffset)
            % Use info from .measurements file to find follicle boundaries
            % and convert Fit Object to series of points (#frame * #points/mask * 2 (for x & y))
            [ imgHeight, imgWidth, ~ ] = size(this.movie);
            entryNum = length(measurements);
            entryIdx = 1;
            this.ptMasks = zeros(length(this.objMasks), numPoints, 2);
            for i = 1:length(this.objMasks)
                minX = inf;
                maxX = 0;
%                 minY = inf;
%                 maxY = 0;
%                 angleY = 0;
                while measurements(entryIdx).fid == i-1
                    if measurements(entryIdx).label ~= -1
                        minX = min(minX, measurements(entryIdx).follicle_x);
                        maxX = max(maxX, measurements(entryIdx).follicle_x);
                        
%                         minY = min(minY, measurements(entryIdx).follicle_y);
%                         maxY = max(maxY, measurements(entryIdx).follicle_y);
                    end
                    if entryIdx < entryNum
                        entryIdx = entryIdx + 1;
                    else
                        break;
                    end
                end
                
                
%                 minX = 1;
                minX = minX - pxPadding*1.2;
                maxX = maxX + pxPadding*1.2;
                minX = MMath.Bound(minX, [1 imgWidth]);
                maxX = MMath.Bound(maxX, [1 imgWidth]);
                
                this.ptMasks(i,:,1) = linspace(minX, maxX, numPoints);
                this.ptMasks(i,:,2) = MMath.Bound(this.objMasks{i}(this.ptMasks(i,:,1)), [1 imgHeight]);
            end
            
%             vx = this.ptMasks(:,:,1);
%             vy = this.ptMasks(:,:,2);
            
%             vx = vx/1.2;      % scale back from 1.2X zoom
%             vy = vy/1.2;      % scale back from 1.2X zoom
            
%             this.ptMasks(:,:,1) = vx;
%             this.ptMasks(:,:,2) = vy;
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
            plot(facemasks(:, ptRange, 2), plotString);
        end
        
        function fm = Offset(fm, offset0, offset1)
            vx = fm(:,:,1);
            vy = fm(:,:,2);
            
            k = (max(vy,[],2) - offset0 + offset1) ./ max(vy,[],2);
            k = repmat(k, size(vx)./size(k));
            
            fm(:,:,1) = vx .* k;
            fm(:,:,2) = vy .* k;
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

