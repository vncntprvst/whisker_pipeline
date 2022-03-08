classdef MwReviewerVM < PipelineBaseClass
    %MWREVIEWERVM Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Models
        reviewee;                       % current trial
        
        % UI data
        curator = '';                   % name of the curator
        hImg;
        
        rvBar = false;                  % reviewing the pole
        rvBarLabel = '';                % the status of bar
        
        profileFacemasks = false;
        
        rvContact = false;
        hPhysFig;
        hContact;
    end
    
    methods
        % Constructor
        function this = MwReviewerVM()
            this.pipressObj = Pipress();
        end
        function val = IsValid(this)
            val = ~isempty(this.pipressObj.pipress) && ~isempty(this.curator);
        end
        
        
        
        % Loads and saves pipress.mat and initialize reviewee
        function success = LoadPipress(this)
            success = false;
            [ ~, folderName ] = Browse.File();
            if folderName % in case user cancels selection
                try
                    % load pipress table
                    this.mainFolder = folderName;
                    this.pipressObj.Load(this.pipressPath);
                    
                    % load the first trial to reviewee as initialization
                    this.LoadTrial(1);
                    
                    success = true;
                catch
                    msgbox('Failed to load Pipress.mat. Please select a valid file.', 'Loading Error');
                end
            end
        end
        function SavePipress(this)
            choice = 'Yes';
            if exist([ this.pipressPath '.mat' ], 'file')
                qstring = 'Do you want to replace the old pipress?';
                choice = questdlg(qstring, 'Save', 'Yes', 'No', 'No');
            end
            if strcmp(choice, 'Yes')
                this.SaveTrial();
                this.pipressObj.Save(this.pipressPath);
            else
                msgbox('Saving is canceled!', 'Canceled');
            end
        end
        
        
        
        % Load and save trial
        function LoadTrial(this, idx)
            currentLabel = this.GetBarStatus(idx);
            
            if any(strcmp(currentLabel, { 'computed', 'found' }))
                this.rvBarLabel = 'curated';
            elseif strcmp(currentLabel, 'error: putative moving bar')
                this.rvBarLabel = 'curated: error moving bar';
            elseif strcmp(currentLabel, 'error: no bar detected')
                this.rvBarLabel = 'curated: error no bar';
            elseif strcmp(currentLabel, 'error: computation failed')
                this.rvBarLabel = 'curated: error computation failed';
            elseif StringTool.MatchRegExps(currentLabel, '^error')
                this.rvBarLabel = 'curated: other error';
            else
                this.rvBarLabel = currentLabel;
            end
            
            delete(this.reviewee);
            this.reviewee = Reviewee(this.mainFolder, idx, this.pipressObj.pipress(idx,:));
            
            if this.profileFacemasks
                this.reviewee.LoadFacemask();
            end
            
            if this.rvContact
                this.reviewee.LoadPhysics();
            end
        end
        function SaveTrial(this)
            idx = this.GetTrialIndex();
            
            if this.rvBar
                % Update bar status in pipress
                this.pipressObj.pipress.bar{idx} = this.rvBarLabel;
                try % in case of encountering MException object
                    this.pipressObj.pipress.bar_r{idx}.curator = this.curator;
                    if this.reviewee.barChanged
                        this.pipressObj.pipress.bar_r{idx}.coordinate = this.reviewee.bartenderObj.polePos;
                    end
                catch
                end
                
                % Save or delete files (bar_gallery image will never be deleted)
                if regexp(this.rvBarLabel, 'error')
                    if this.reviewee.DeleteBar()
                        disp('Bar file removed');
                    end
                else
                    if this.reviewee.barChanged
                        if ~this.reviewee.SaveBar(true)
                            msgbox('The trial was NOT saved!', 'Error');
                        end
                    else
                        if this.reviewee.SaveBar(false);
                            disp('New bar file added');
                        end
                    end
                end
            end
        end
        function switched = SwitchTrial(this, newTrialIndex)
            switched = false;
            currentTrialIndex = this.GetTrialIndex();
            totalTrialNum = size(this.pipressObj.pipress, 1);
            
            % Make sure it is a new trial and not exceeding the boundaries of trial list
            if newTrialIndex ~= currentTrialIndex && newTrialIndex <= totalTrialNum && newTrialIndex > 0
                this.SaveTrial();
                this.LoadTrial(newTrialIndex);
                switched = true;
            end
        end
        function switched = NextTrial(this)
            newTrialIndex = this.GetTrialIndex() + 1;
            switched = this.SwitchTrial(newTrialIndex);
        end
        function switched = LastTrial(this)
            newTrialIndex = this.GetTrialIndex() - 1;
            switched = this.SwitchTrial(newTrialIndex);
        end
        
        
        
        % To UI
        function [ tableContent, columnName ] = GetPipressTable(this)
            charPipress = this.pipressObj.GetCharPipress();
            ind = Pipress.GetExcelRange;
            ind(4:9) = [];
            columnName = this.pipressObj.variableNames(ind);
            tableContent = charPipress{:,ind};
        end
        function tableColumn = GetTrialNamePipress(this)
            tableColumn = this.pipressObj.pipress.trialName;
        end
        function idx = GetTrialIndex(this)
            idx = this.reviewee.trialIndex;
        end
        function barStatus = GetBarStatus(this, idx)
            if nargin < 2
                idx = this.GetTrialIndex();
            end
            barStatus = this.pipressObj.pipress.bar{idx};
        end
        
        function ShowMarkedImage(this)
            this.hImg = imshow(this.reviewee.GetMarkedImage());
        end
        function ShowFacemask(this)
            fm = this.pipressObj.pipress.facemasks_r{GetTrialIndex(this)};
            if isnumeric(fm) && ~isempty(fm)
                plot(fm(:,1), fm(:,2), 'r', 'LineWidth', 4);
                if this.profileFacemasks && ~isempty(this.reviewee.facemasks)
                    figure(1);
                    Masquerade.PlotMaskProfile(this.reviewee.facemasks, 'r', 1:2:10);
                    hold on;
                    Masquerade.PlotMaskProfile(Masquerade.Filter(this.reviewee.facemasks), 'b', 1:2:10);
                    hold off;
                end
            else
                disp('Facemask not available ...');
            end
        end
        function ShowRainbowFacemask(this)
            if isempty(this.reviewee.facemasks)
                if ~this.profileFacemasks
                    disp('Facemask not loaded ...');
                else
                    disp('Facemask not available ...');
                end
            else
                Masquerade.PlotRainbowMasks(this.reviewee.facemasks, 2);
            end
        end
        function ShowContactProfile(this)
            if this.rvContact
                if isempty(this.reviewee.wl)
                    disp('Physics not available ...');
                    beep;
                else
                    if ishandle(this.hPhysFig)
                        figure(this.hPhysFig);
                    else
                        this.hPhysFig = figure(2);
                        set(gcf, 'Color', 'w');
                    end
                    this.reviewee.wl.plot_contact_profile();
                end
            end
        end
        function ShowMartiny(this, loadRawTrajectories)
            Martiny(loadRawTrajectories, true, true, 'tifPath', fullfile(this.reviewee.trialFolder, [ this.reviewee.trialName, '.tif' ]));
        end
        
        
        % From UI
        function success = SetPolePos(this)
            success = false;
            if this.rvBar
                try
                    h = impoint;                                % allow user to select the pole center
                    xy = round(getPosition(h));                 % get the xy coordinates in integers
                    delete(h);                                  % remove impoint to prevent bug
                    
                    this.reviewee.ChangePolePos(xy);            % logging
                    hold on;
                    plot(xy(1), xy(2), 'r+', 'MarkerSize', 12);  % superimpose the new point
                    hold off;
                    success = true;
                    this.rvBarLabel = 'curated';
                catch
                    disp('selection aborted');
                end
            end
        end
        function SetPoleLabel(this, barLabel)
            if this.rvBar
                if ~strcmp(barLabel, 'curated')
                    barLabel = [ 'curated: ' barLabel ];
                end
                this.rvBarLabel = barLabel;
            end
        end
    end
    
end

