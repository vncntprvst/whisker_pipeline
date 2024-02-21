% sanity check: single file
fileNum=1;
fileName=include_files{fileNum};
syscall = ['C:\Progra~1\WhiskerTracking\bin\trace ' fileName ext ' ' fileName '.whiskers']; disp(syscall); system(syscall);
syscall = ['C:\Progra~1\WhiskerTracking\bin\measure --face ' num2str(face_x_y)...
    ' x  ' fileName '.whiskers ' fileName '.measurements']; disp(syscall); system(syscall);
syscall = ['C:\Progra~1\WhiskerTracking\bin\classify ' fileName '.measurements ' ...
    fileName '.measurements ' num2str(face_x_y) ' x --px2mm 0.064 -n ' ...
    num2str(num_whiskers) ' --limit2.0:50.0']; %--limit2.0:50.0'
disp(syscall); system(syscall);

%% Test performence with one trial
if false
    % Initialize object
    % ow = OneWhisker('path', filePath, 'silent', false, ...
    %     'whiskerID', 0, ...
    %     'distToFace', 30, ... % for face mask
    %     'polyRoiInPix', [31 163], ... % point of interest on whisker close to pole
    %     'rInMm', 4.5, ... %point where curvature is measured
    %     'whiskerRadiusAtBaseInMicron', 44, ... %post-hoc measurement
    %     'whiskerLengthInMm', 25.183, ...    %post-hoc measurement
    %     'faceSideInImage', 'top', ...
    %     'protractionDirection', 'leftward',...
    %     'linkingDirection','rostral',...
    %     'whiskerpadROI',whiskerPadCoordinates,...
    %     'whiskerLengthThresh',50,...
    %     'silent',true); % caudal or rostral

    % Then link
    % ow.LinkWhiskers('Force', true);            % see Guide for the detail about 'Force'

    % Additional processing
    % ow.MakeMasks('Force', true);
    % ow.DetectBar('Force', true);
    % ow.DoPhysics('Force', true);

    %% Loop through session
    for fileNum=1:numel(include_files)
        fileName=include_files{fileNum};
        filePath = fullfile(sessionDir, 'WhiskerTracking', [fileName '.measurements']); %'D:\Vincent\vIRt43\vIRt43_1204\WhiskerTracking\vIRt43_1204_4400_20191204-171925_HSCam_Trial0.measurements';
        ow = OneWhisker('path', filePath, 'silent', false, ...
            'whiskerID', 0, ...
            'distToFace', 30, ... % for face mask
            'polyRoiInPix', [31 163], ... % point of interest on whisker close to pole
            'rInMm', 4.5, ... %point where curvature is measured
            'whiskerRadiusAtBaseInMicron', 44, ... %post-hoc measurement
            'whiskerLengthInMm', 25.183, ...    %post-hoc measurement
            'faceSideInImage', 'top', ...
            'protractionDirection', 'leftward',...
            'linkingDirection','rostral',...
            'whiskerpadROI',whiskerPadCoordinates,...
            'whiskerLengthThresh',50,...
            'silent',true); % caudal or rostral

        % Link
        ow.LinkWhiskers('Force', true);            % see Guide for the detail about 'Force'

        % Save
        ow.objStruct.measurements.Save([include_files{fileNum} '_curated.measurements']);
    end

    %% Link whole session
    if ~exist([sessionDir filesep 'settings'],'dir')
        mkdir([sessionDir filesep 'settings']);
    end
    mw = ManyWhiskers([sessionDir filesep 'WhiskerTracking'], ...
        'sessionDictPath', [sessionDir filesep 'settings' filesep 'session_dictionary.xlsx'], ... % where session info are saved
        'sessionDictEntryIdx', NaN, ...
        'measurements', true,...
        'bar', false, ...
        'facemasks', false, ...
        'physics', false, ...
        'contact', false);

    %% Other Linking methods
    % Using Reclassify script
    % Classify only 5 whiskers now
    num_whiskers=3;
    for fileNum=1:numel(include_files)
        syscall = ['C:\Progra~1\WhiskerTracking\bin\measure --face ' num2str(whiskerPadLocation)...
            ' x  ' fileName '.whiskers ' fileName '.measurements']; disp(syscall); system(syscall);
        syscall = ['C:\Progra~1\WhiskerTracking\bin\classify ' fileName '.measurements ' ...
            fileName '.measurements ' num2str(whiskerPadLocation) ' x --px2mm 0.064 -n ' ...
            num2str(num_whiskers) ' --limit2.0:50.0']; %--limit2.0:50.0'
        disp(syscall); system(syscall);
        sysCall = ['C:\Progra~1\WhiskerTracking\bin\reclassify -n ' num2str(num_whiskers)...
            ' ' include_files{fileNum} '.measurements ' include_files{fileNum} '.measurements'];
        disp(sysCall);
        system(sysCall);
    end

    % Using Whisker linker
    for fileNum=1:numel(include_files)
        try
            %Load measurements
            measurementsPath=[include_files{fileNum} '.measurements'];
            trialMeasurements = Whisker.LoadMeasurements(measurementsPath);
            % Link across frames
            linkedMeasurements = WhiskerLinkerLite(trialMeasurements);
            %Save output
            Whisker.SaveMeasurements(measurementsPath,linkedMeasurements.outMeasurements);
        catch
        end
    end

    %Plot input
    dt=0.002;
    time=double([linkedMeasurements.measurements(:).fid]).*dt;
    angle=[linkedMeasurements.measurements(:).angle];
    colors=['r','g','b','k','c','m'];
    figure;clf;
    hold on;
    for whisker_id=1%:max([linkedMeasurements.measurements(:).label])
        mask = [linkedMeasurements.measurements(:).label]==whisker_id;
        plot(time(mask),angle(mask),colors(whisker_id+1));
    end

    %Plot output
    dt=0.002;
    time=double([linkedMeasurements.outMeasurements(:).fid]).*dt;
    angle=[linkedMeasurements.outMeasurements(:).angle];
    colors=['r','g','b','k','c','m'];
    figure;clf;
    hold on;
    for whisker_id=0%:max([linkedMeasurements.outMeasurements(:).label])
        mask = [linkedMeasurements.outMeasurements(:).label]==whisker_id;
        plot(time(mask),angle(mask),colors(whisker_id+1));
    end

end
