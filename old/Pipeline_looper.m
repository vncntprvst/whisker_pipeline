%% From physics to contact detection

mainFolders = findfiles_all_subpath('\\OCONNORDATA3\data3\projectData\TGworkspace3\workspace');

mainFolders = cellfun(@fileparts, mainFolders, 'Uni', false);
mainFolders = natsort(mainFolders);
[~, folderNames] = cellfun(@fileparts, mainFolders, 'Uni', false);

folderMask = listdlg('ListString', folderNames, 'SelectionMode', 'multiple', 'ListSize', [ 400 600 ]);
mainFolders = mainFolders(folderMask);


% You must have already:
% done linking, facemasking, bar detection, bar curation
% populated parameters of whisker ROI and the point of measurement

for i = 1 : length(mainFolders)
    
    disp(mainFolders{i});
    clear mw ct
    
    % Backup previous kappa_param.mat, pipress, clasifier, and all _WL.mat files
    bkFolder = fullfile(mainFolders{i}, 'backup 20161208');
    mkdir(bkFolder);
    try
        copyfile(fullfile(mainFolders{i}, 'kappa_param.mat'), bkFolder);
    catch
    end
    try
        copyfile(fullfile(mainFolders{i}, 'classifier.mat'), bkFolder);
    catch
    end
    try
        copyfile(fullfile(mainFolders{i}, 'pipress.mat'), bkFolder);
    catch
    end
    try
        copyfile(fullfile(mainFolders{i}, 'pipress.xls'), bkFolder);
    catch
    end
    
    mkdir(fullfile(bkFolder, 'WL'));
    try
        copyfile(fullfile(mainFolders{i}, 'workspace', '*_WL.mat'), fullfile(bkFolder, 'WL'));
    catch
    end
    
    
    
    % Reinitialize ManyWhisker object
    mw = ManyWhiskers(mainFolders{i}, ...
        'bar', false, ...
        'facemasks', false, ...
        'contact', false);
    
    % Compute physics with zero baseline kappa
    mw.kappaParam = 0;
    mw.pipressObj.pipress.physics = repmat({'redo'}, size(mw.pipress,1), 1);    % changes physics status to redo
    mw.Start();                                                                 % computing physical quantities again
    
    % Backup results with zero baseline kappa
    mkdir(fullfile(mainFolders{i}, 'workspace', 'zero baseline physics'));
    try
        copyfile(fullfile(mainFolders{i}, 'workspace', '*_WL.mat'), fullfile(mainFolders{i}, 'workspace', 'zero baseline physics'));
    catch
    end
    
    % Compute and save baseline kappa fit
    figure(8239); clf
    mw.GetBaselineKappaFit();
    
    % Compute physics with fitted baseline kappa
    mw.pipressObj.pipress.physics = repmat({'redo'}, size(mw.pipress,1), 1);    % changes physics status to redo
    mw.Start();                                                                 % computing physical quantities again
    
    
    
    % STEP I: Initialize ContactTrainer object and load training datasets
    ct = ContactTrainer(mainFolders{i});
    ct.LoadDataset(true);                           % you may select which trials to include
    
    % STEP II: Traning and self-testing(OOB)
    ct.Train();                         % train the Random Forest classifier
    ct.Test('oob');                     % OOB auto contact detection
    ct.SaveTrials();                    % save new WhiskerTrialLite objects (in which contactAuto and contactScore properties are filled)
    
    % STEP V: Finalizing and saving
    ct.SaveClassifier(fullfile(mainFolders{i}, 'classifier.mat'));      % save classifier for contact detection
    ct.SaveObject('\\OCONNORDATA3\data3\projectData\UnitData');         % save ContactTrainer object
    
    
    
    % Reinitialize ManyWhisker object
    mw = ManyWhiskers(mainFolders{i}, ...
        'bar', false, ...
        'facemasks', false);
    
    mw.pipressObj.pipress.contacts = repmat({'redo'}, size(mw.pipress,1), 1);    % changes physics status to redo
    mw.Start();
        
end





%% Looping through all units for merging

mainFolders = findfiles_all_subpath('\\OCONNORDATA9\data9b\projectData\FacePro\NMworkspace9b\workspace');

mainFolders = cellfun(@fileparts, mainFolders, 'Uni', false);
mainFolders = natsort(mainFolders);
[~, folderNames] = cellfun(@fileparts, mainFolders, 'Uni', false);

folderMask = listdlg('ListString', folderNames, 'SelectionMode', 'multiple', 'ListSize', [ 400 600 ]);
mainFolders = mainFolders(folderMask);

for i = 1 : length(mainFolders)
    
    clear ue s spikesTrialArrayObj whiskerTrialLiteArrayObj
    
    % Load WhiskerTrialLites to WhiskerTrialLiteArray
    whiskerTrialLiteArrayObj = Whisker.WhiskerTrialLiteArray(fullfile(mainFolders{i}, 'workspace'));
    
    % Load SweepArray
    cd(mainFolders{i})
    sweepArrayPath = dir('sweepArray*');
%     sweepArrayPath = Browse.File(mainFolders{i});
    load(sweepArrayPath.name);
    spikesTrialArrayObj = s.get_sorted_spike_times();
    
    % Create UnitExplorer
    ue = TG.UnitExplorer(spikesTrialArrayObj, whiskerTrialLiteArrayObj, false);
    % ue.ShowSummary();  % if you missed the plot
    
    % Save UnitExplorer
    ue.SaveObject('\\OCONNORDATA3\data3\projectData\UnitData_recalc\UnitDataTesting');
    
%     input([ num2str(i) ': ' ue.sessionName ' has finished. Input anything to continue.']);
    clc;
    pause(0.1);
end

% Merging cannot be done automatically because:
%   Unqualified _WL.mat files (remnants from previous runs) are better to be removed with our
%   inspection in case hundreds of files are deleted due to whatever reason.
%   SweepArray files may not all have the same naming convention.





%% Benchmark ContactTrainer objects in a loop

ctPaths = Browse.Files('\\OCONNORDATA3\data3\projectData\UnitData');

[~, ctNames] = cellfun(@fileparts, ctPaths, 'Uni', false);
ctNames = cellfun(@(x) x(16:end), ctNames, 'Uni', false);


for i = length(ctPaths) : -1 : 1
    clear ct
    load(ctPaths{i});
    cts{i} = ct;
end

figure(585274)
figure(585275)

for i = 1 : length(ctPaths)
    
    ct = cts{i};
    ct.bootstrpTable = [];          % don't do this if you just want to append iterations
    numIter = 20;
    ct.Test('bootstrap', numIter);
    save(ctPaths{i}, 'ct');         % save ContactTrainer object
    
    ct.ShowOobTransitionErr();      % optionally accepts a peri-transition range (default -1:0)
    MPlot.SaveFigure(gcf, [ctNames{i} ' transition']);
%     savefig(gcf, [ctNames{i} ' transition']);
    
    ct.ShowBootstrapErr();          % optionally accepts a boolean value to plot AUCs
    ylim([0 0.1]);
    MPlot.SaveFigure(gcf, [ctNames{i} ' bootstrap']);
%     savefig(gcf, [ctNames{i} ' bootstrap']);
    
end




