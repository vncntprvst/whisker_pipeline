classdef Bartender < handle
    %BARTENDER Summary of this class goes here
    % word "bar" was avoided in the code due to MATLAB built-in function bar()
    % pole as a variable means the smaller templates for fine localization
    % pole_template.mat as a file name means all templates together
    
    properties
        % Image and Templates
        img = [];       % image
        arm = [];       % template of arm, for global localization
        pole = [];      % template of bar(pole) for local fine tunning
        
        % Runtime variables
        msRough;
        fRough;
        sRoughRF;
        msNorm;
        fNorm;
        sNormRF;
        
        % Outputs
        polePos;    % final bar center coordinates
        minMSE;     % minimal mean squared error indicate the goodness of detection
    end
    
    methods
        function this = Bartender(varargin)
            % Parse inputs
            p = inputParser();
            p.addParameter('Image', [], @isnumeric);
            p.addParameter('FrameIndex', 1, @isnumeric);
            p.parse(varargin{:});
            this.img = p.Results.Image;
            frIdx = p.Results.FrameIndex + 1;
            
            % Prompt UI for user to import image if no direct image input
            if isempty(this.img)
                tifPath = Browse.File();
                this.img = Img23.ImportMP4(tifPath, 'range', [ frIdx frIdx ]);
                this.ShowImage();
            end
        end
        
        function ShowImage(this)
            figure; imshow(this.img);
        end
        
        
        function Tend(this, varargin)
            % Parse inputs
            p = inputParser();
            p.addParameter('Arm', this.arm, @isnumeric);
            p.addParameter('Pole', this.pole, @isnumeric);
            p.parse(varargin{:});
            this.arm = p.Results.Arm;
            this.pole = p.Results.Pole;
            
            % Ask user for pole_templates.mat file if no template is provided directly
            if isempty(this.arm) || isempty(this.pole)
                [ fileName, folderName ] = uigetfile('*.mat');
                load(fullfile(folderName, fileName));
                this.arm = arm;
                this.pole = pole;
            end
            
            % Create rough version of images
            roughFactor = 8;
            frRough = ImageShrink(this.img, roughFactor);
            armRough = ImageShrink(this.arm, roughFactor);

            % Define boundary
            msRoughSize = size(frRough) - 4;
            msNormSize = [ roughFactor*4, roughFactor*4 ];

            % 0.125X complex RF screening
            msRoughStack = zeros([ msRoughSize, size(this.arm,3) ]);
            for i = 1 : size(this.arm, 3)
                msRoughStack(:,:,i) = XMeanSquare2v2(frRough, armRough(:,:,i), 'OutputSize', msRoughSize);
            end
            [ ~, idx ] = min(msRoughStack(:));
            [ roughFocus(1), roughFocus(2), roughSubRF ] = ind2sub(size(msRoughStack), idx);

            this.msRough = msRoughStack;
            this.fRough = roughFocus - 0.5 - 1; % focus on pixel center (empirically -1)
            this.sRoughRF = roughSubRF;

            % Reduce the #candidate of pole templates
            iSet = ceil(roughSubRF / 3);
            rPole = this.pole(:, :, iSet*2-1:iSet*2);

            % 1X complex RF screening
            nextFocus = round((this.fRough+2) * roughFactor); % convert focus coordiante back to 1X
            msNormStack = zeros([ msNormSize, size(rPole,3) ]);
            for i = 1 : size(rPole, 3)
                msNormStack(:,:,i) = XMeanSquare2v2(this.img, rPole(:,:,i), ...
                    'OutputSize', msNormSize, 'Focus', nextFocus);
            end
            [ this.minMSE, idx ] = min(msNormStack(:));
            [ normFocus(1), normFocus(2), normSubRF ] = ind2sub(size(msNormStack), idx);

            this.msNorm = msNormStack;
            this.fNorm = normFocus;
            this.sNormRF = normSubRF;

            % Convert back to overall position
            shiftNorm = normFocus - size(msNormStack(:,:,1))/2; % Shift in 1X sub-image
            normFocus = nextFocus + shiftNorm; % Focus position in whole 1X image
            polePosition = normFocus - 1; % empirically -1
            polePosition = flip(polePosition);
            this.polePos = polePosition;
        end
        
        % Quality control for out-of-frame error
        function val = IsValid(this)
            val = true;
            if this.polePos(1) < 1 || this.polePos(1) > size(this.img,2)
                val = false;
            end
            if this.polePos(2) < 1 || this.polePos(2) > size(this.img,1)
                val = false;
            end
        end
        
        % Quality control for moving-bar error
        function val = IsMoved(this, that, threshold)
            if nargin < 3
                threshold = 20;
            end
            dx = abs(this.polePos(1) - that(1));
            dy = abs(this.polePos(2) - that(2));
            val = dx > threshold || dy > threshold;
        end
        
        
        
        
        % Display detection result
        function ShowResult(this)
            nRough = size(this.msRough,3);
            nNorm = size(this.msNorm,3);
            nRow = nRough/3 + nNorm/2;
            
            figure
            for i = 1 : nRough
                subplot(nRow, 3, i);
                imagesc(this.msRough(:,:,i));
                axis equal tight;
                if i == this.sRoughRF
                    hold on
                    plot(this.fRough(2)+1, this.fRough(1)+1, 'o', 'Color', 'y', 'MarkerSize', 5);
                    hold off
                    axis ij equal tight;
                end
            end
            
            for i = 1 : nNorm
                subplot(nRow, 3, nRough + i);
                imagesc(this.msNorm(:,:,i));
                axis equal tight;
                if i == this.sNormRF
                    hold on
                    plot(this.fNorm(2), this.fNorm(1), 'o', 'Color', 'y', 'MarkerSize', 5);
                    hold off
                    axis ij equal tight;
                end
            end
            
            figure
            imshow(this.img);
            hold on
            plot(this.polePos(1), this.polePos(2), '+', 'Color', 'y', 'MarkerSize', 5);
            hold off
            axis ij equal tight;
        end
        
        % Save detection result to .bar file
        function SaveBarFile(this, folderName, fileName)
            poleInfo = [ (0:2499)' repmat(this.polePos, 2500, 1) ]';
            fileID = fopen(fullfile(folderName, [ fileName '.bar' ]),'w');
            fprintf(fileID,'%d,%d,%d\r\n', poleInfo);
            fclose(fileID);
        end
        
        % Delete .bar file
        function DeleteBarFile(~, folderName, fileName)
            delete(fullfile(folderName, [ fileName '.bar' ]));
        end
        
        % Save marked image
        function SaveImage(this, filePath, rgbImg)
            if nargin > 2 && size(rgbImg,3) == 3
            	imgMarked = cat(3, zeros(size(rgbImg(:,:,1)), 'like', rgbImg), rgbImg(:,:,2:3));
            else
                imgMarked = repmat(this.img, 1, 1, 3);
            end
            try % in case pole position is outside of the frame
                imgMarked(this.polePos(2)-2:this.polePos(2)+2, this.polePos(1)-2:this.polePos(1)+2, 1) = 255;
            catch
            end
            imwrite(imgMarked, filePath);
        end
        
        
        
        
        
        function MakeTemplates(this, varargin)
            p = inputParser();
            p.addParameter('Mode', 'add', @ischar);
            p.addParameter('TemplatePath', 'pole_template.mat', @ischar);
            p.parse(varargin{:});
            mode = p.Results.Mode;
            templatePath = p.Results.TemplatePath;
            
            if strcmp(mode, 'add')
                try % try loading existing templates
                    load(templatePath);
                    oldArm = arm;
                    oldPole = pole;
                catch % if no template available, switch to new templates creating mode
                    mode = 'new';
                end
            end
            
            % Specify template sizes
            awr = 50;   % half window size(pixels) of the raw arm ROI (before rotation)
            aw = 32;    % half window size(pixels) of the arm ROI (after rotation)
            pw = 10;    % half window size(pixels) of the pole ROI
            
            % Select the pole center
            figure('Name', 'Click at the pole center');
            imagesc(imadjust(this.img));    % display the image
            axis equal tight off
            colormap gray
            h = impoint;    % allow user to select the pole center
            xy = round(getPosition(h));     % get the xy coordinates in integers
            
            % Create template subunits
            armRaw = this.img(xy(2)-awr : xy(2)+awr, xy(1)-awr : xy(1)+awr);	% crop out the raw arm ROI
            armRaw(:,:,2) = imrotate(armRaw(:,:,1), 45, 'crop');  % append a rotated version
            armRaw(:,:,3) = imrotate(armRaw(:,:,1), 90, 'crop');  % append a rotated version
            ij = round(size(armRaw(:,:,1))/2);  % find the center of raw arm ROI
            arm = armRaw(ij(1)-aw : ij(1)+aw, ij(2)-aw : ij(2)+aw, :);
            
            pole = this.img(xy(2)-pw : xy(2)+pw, xy(1)-pw : xy(1)+pw);	% crop out pole ROI
            pole(:,:,2) = imrotate(pole, 90, 'crop');    % append a rotated version
            
            % Combine templates
            if strcmp(mode, 'add')
                arm = cat(3, oldArm, arm);
                pole = cat(3, oldPole, pole);
            end
            this.arm = arm;
            this.pole = pole;
            save(templatePath, 'arm', 'pole');
            
            this.ShowTemplates();
        end
        
        % Display templates
        function ShowTemplates(this)
            figure
            maxSubRF = max(size(this.arm,3), size(this.pole,3)); % find the #columns of subplots
            for i = 1 : size(this.arm,3)
                subplot(2, maxSubRF, i);
                imshow(this.arm(:,:,i));
            end
            for i = 1 : size(this.pole,3)
                subplot(2, maxSubRF, size(this.arm,3)+i);
                imshow(this.pole(:,:,i));
            end
        end
        
    end
    
end

