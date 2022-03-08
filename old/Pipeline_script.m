%% Video Parser (for continuous video acquisition)
% Wrap into function with options for ephys and video

%% Whisker tracking (local only for now)
% Wrap into function with inputs for whisker pad position, num whiskers,
% etc.

%% Make pole templates

% Folder path for saving the template
pathMainFolder = Browse.Folder();

% Create Bartender object with an appropriate frame (not at the edges and free of interference)
% Martiny(false, false, false);           % may want to use Martiny to find a good frame
barObj = Bartender('FrameIndex', 147);    % use a frame to initialize

% Create ('Mode', 'new') or add ('Mode', 'add') the detection templates
barObj.MakeTemplates('TemplatePath', fullfile(pathMainFolder, 'pole_template'), 'Mode', 'new');

barObj.ShowTemplates();

%% Pre-training

% PART I - measurement, linking, bar detection, facemasking and bar curation

% Edit entry with recording ID in session dictionary file in default
% pipeline info folder (change excel format to csv to make more general
% across systems)

% First-time initialization of ManyWhisker object
pathMainFolder = Browse.Folder();       % where pipress resides (or will reside)
pathSessionInfoDict = 'Z:\all_staff\Wenxi\default pipeline info\session_dictionary.xlsx';
% pathSessionInfoDict = 'Z:\all_staff\Kyle\Sharing\NewWhiskerTrackingPipeline\defaultPipelineInfo\session_dictionary.xlsx';
mw = ManyWhiskers(pathMainFolder, ...
    'sessionDictPath', pathSessionInfoDict, ...
    'sessionDictEntryIdx', 1);          % the #th entry of this session in the session info dictionary

% Start paralell processing and does linking, bar detection and facemasking (or as much as it can)
mw.Start();

% Go to MwReviewer to curate the bar results
MwReviewer;

% PART II - curvature ROI and the point of measurement, uncorrected delta kappa
% Find whiskerROI and the point of measurement (only allowed after curating bar results)
mw.GetPhysParam( ...
    'proximalRoi', 1, ...       % default 1 mm
    'minDistalRoi', 4, ...      % default 4 mm
    'maxDistalRoi', 4, ...      % default 6 mm
    'minBarToRoi', 0.5, ...       % default 1 mm
    'rToDistalRoi', 0.5);       % default 0.5 mm

% Reinitialize ManyWhisker object to pick up changed status during bar curation
pathMainFolder = Browse.Folder();       % where pipress resides (or will reside)
mw = ManyWhiskers(pathMainFolder, 'contact', false);

% Compute physical quantities with zero baseline kappa
% mw.pipressObj.pipress.distToFace = repmat({-5}, size(mw.pipress,1), 1); 
% mw.pipressObj.pipress.measurements = repmat({'none'}, size(mw.pipress,1), 1); 
% mw.pipressObj.pipress.bar = repmat({'none'}, size(mw.pipress,1), 1); 
% mw.pipressObj.pipress.facemasks = repmat({'none'}, size(mw.pipress,1), 1); 
% mw.pipressObj.pipress.physics = repmat({'none'}, size(mw.pipress,1), 1); 
% mw.pipressObj.pipress.contacts = repmat({'none'}, size(mw.pipress,1), 1); 
% mw.pipressObj.pipress.r = repmat({NaN}, size(mw.pipress,1), 1); 
mw.Start();

% PART III - baseline kappa fit, corrected delta kappa and physical quantities
% Compute and save baseline kappa fit
[kappa_param, ~] = mw.GetBaselineKappaFit();

mw.pipressObj.pipress.physics = repmat({'redo'}, size(mw.pipress,1), 1);    % changes physics status to redo
mw.Start();                                                                 % computing physical quantities again

% mw.ChangeFacemaskOffset(oldVal, newVal);
mw.ChangeFacemaskOffset(15, 30);

%% Check and unify contact files

% Manually classify contact frames in Martiny GUI
Martiny

% Finds paths of contact files
pathContactFiles = Browse.Files();

% Check the completeness of information
cellfun(@(x) ContactTrainer.UpdateContactFileInfo(x, 'checkOnly', true), pathContactFiles, 'UniformOutput', false);

% Suitable for info update with individual modifications
cellfun(@(x) ContactTrainer.UpdateContactFileInfo(x, 'forcedPrompt', true), pathContactFiles, 'UniformOutput', false);

% Suitable for info update with identical batch modifications (use with caution!)
cellfun(@(x) ContactTrainer.UpdateContactFileInfo(x, ...
    'detector', 'WX', ...
    'date', '17-May-19', ...
    'trajectory', 0), ...
    pathContactFiles, 'UniformOutput', false);

%% Train classifier

% STEP I: Initialize ContactTrainer object and load training datasets
pathMainFolder = Browse.Folder();           % folder path that contains pipress
ct = ContactTrainer(pathMainFolder);
ct.LoadDataset();                           % you may select which trials to include

% STEP II: Traning and self-testing(OOB)
ct.Train();                         % train the Random Forest classifier
ct.Test('oob');                     % OOB auto contact detection
ct.SaveTrials();                    % save new WhiskerTrialLite objects (in which contactAuto and contactScore properties are filled)

% STEP III: Go to MwReviewer to curate the manual contact detections
% MwReviewer;

% STEP IV: Benchmarking
% run STEP I and II again, and then ...
ct.Test('bootstrap');                % optionally accepts #iterations (default 20) and #trials for training (default 1:3:end-3)
ct.ShowBootstrapErr();              % optionally accepts a boolean value to plot AUCs
ct.ShowOobTransitionErr();         % optionally accepts a peri-transition range (default -1:0)


% STEP V: Finalizing and saving
% if you are NOT satisfied with the results
% 1) add more curated trials and redo their physics
% 2) run the ENTIRE "Train classifier" section again
ct.SaveClassifier(fullfile(pathMainFolder, 'classifier.mat'));      % save classifier for contact detection
ct.SaveObject(pathMainFolder);                                      % save ContactTrainer object



%% Post-training

% Reinitializes ManyWhisker object to pick up the classifier
pathMainFolder = Browse.Folder();       % where pipress resides (or will reside)
mw = ManyWhiskers(pathMainFolder);

% Load SweepArray
sweepArrayPath = Browse.File();
load(sweepArrayPath);
spikesTrialArrayObj = s.get_sorted_spike_times();

% Contact classification
mw.pipressObj.pipress.contacts = repmat({'redo'}, size(mw.pipress,1), 1);   % changes contact status to redo
mw.Start();
% mw.CleanPhysicsFiles();     % Eliminates unqualified _WL.mat files

% Combine WhiskerTrialLites with SweepArray
% Load WhiskerTrialLites to WhiskerTrialLiteArray
% pathMainFolder = Browse.Folder();
whiskerTrialLiteArrayObj = Whisker.WhiskerTrialLiteArray(fullfile(pathMainFolder, 'workspace'));

% Create UnitExplorer
ue = PrV.UnitExplorer(spikesTrialArrayObj, whiskerTrialLiteArrayObj);
% ue.ShowSummary();  % if you missed the plot

% Save UnitExplorer
ue.SaveObject(pathMainFolder);

%% Single trial processing

% Path of any file whose file name is the trial common name (e.g. xxx.tif)
% make sure other related files are in the same folder
filePath = Browse.File();

% Initialize object
% set 'silent' to false so that we can get prompts and/or plots (if any)
ow = OneWhisker('path', filePath, 'silent', false, ...
    'whiskerID', 0, ...
    'distToFace', 30, ...
    'polyRoiInPix', [31 163], ...
    'rInMm', 4.5, ...
    'whiskerRadiusAtBaseInMicron', 44, ...
    'whiskerLengthInMm', 25.183, ...
    'faceSideInImage', 'bottom', ...
    'protractionDirection', 'leftward');

% Step by step processing
ow.LinkWhiskers('Force', true);            % see Guide for the detail about 'Force'

ow.DetectBar('Force', true);   % additional inputs, 'arm' and 'pole', are in pole_template.mat
% ow.checkTable.status{3} = 'curated';

ow.MakeMasks('Force', true);

ow.checkTable.status{3} = 'curated';
ow.DoPhysics('Force', true);

load('classifier.mat')
ow.DetectContacts(classifier);                    % variable 'cObj' is in classifier.mat



