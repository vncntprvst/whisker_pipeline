function whiskerTrackingDataFile=LoadWhiskerData
whiskerTrackDir=cd; dirListing=dir(whiskerTrackDir);
whiskerDataFiles = cellfun(@(flnm) contains(flnm,'whisker') || contains(flnm,'Whisker'),{dirListing.name});
whiskerDataFiles={dirListing(whiskerDataFiles).name};
if numel(whiskerDataFiles)>1
    %     ??
end
whiskerTrackFileName= whiskerDataFiles{1};

if contains(whiskerTrackFileName,'.npy')
elseif contains(whiskerTrackFileName,'.csv') % e.g. WhiskerAngle.csv
    if contains(whiskerTrackFileName,'DeepCut') || contains(whiskerTrackFileName,'DLC')
        whiskerTrackingData = ImportDLCWhiskerTrackingCSV(fullfile(...
            whiskerTrackDir,whiskerTrackFileName));
    else %assuming from Bonsai
        %             depending on version, export from Bonsai has either
        %               one column: Orientation
        %               three columns:  Centroid.X Centroid.Y Orientation
        %               6 times three columns: Base, Centroid.X and Centroid.Y for each whisker
        if numel(wTrackNumFile)==1
            if contains(whiskerTrackFileName,'BaseCentroid')
                whiskerTrackingData=readtable(fullfile(whiskerTrackDir,whiskerTrackFileName));
                whiskerTrackingData=ContinuityWhiskerID(whiskerTrackingData);
            else
                delimiter=' ';hasHeader=false;
                whiskerTrackingData=ImportCSVasVector(...
                    fullfile(whiskerTrackDir,whiskerTrackFileName),delimiter,hasHeader);
                if size(whiskerTrackingData,2)>1
                    whiskerTrackingData=whiskerTrackingData(:,1:2);
                end
            end
        else
            whiskerTrackDir=whiskerAngleFiles(wTrackNumFile(2)).folder;
            whiskerTrackFileName= whiskerAngleFiles(wTrackNumFile(2)).name;
            multiWhiskerTrackingData=ImportCSVasVector(fullfile(whiskerTrackDir,whiskerTrackFileName));
            % Multiwhiskerfor up to 5 main whiskers (NaN if less)
            whiskerTrackingData=multiWhiskerTrackingData(:,7); %posterior most whisker
        end
        whiskerTrackingData=WhiskerAngleSmoothFill(whiskerTrackingData); %(:,1),whiskerTrackingData(:,2));
    end
elseif contains(whiskerTrackFileName,'.avi') %video file to extract whisker angle
    whiskerTrackingData=ExtractMultiWhiskerAngle_FFTonContours(fullfile(dirName,fileName));
    whiskerTrackingData=smoothdata(whiskerTrackingData,'rloess',20);
else
    whiskerTrackingData = load(whiskerTrackFileName);
end

save('whiskerTrackingData','whiskerTrackingData');
whiskerTrackingDataFile.name='whiskerTrackingData.mat';
whiskerTrackingDataFile.folder=cd;
