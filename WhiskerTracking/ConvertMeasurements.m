function ConvertMeasurements(mFilesDir)

if ~nargin; mFilesDir=cd; end

mFiles = cellfun(@(fileFormat) dir([mFilesDir filesep fileFormat]),...
    {'*.measurements'},'UniformOutput', false);
mFiles=vertcat(mFiles{~cellfun('isempty',mFiles)});

nfiles = length(mFiles);

if ~isempty(mFiles)
    parfor fNum=1:nfiles
        % disp(['Converting file '  fn ', ' int2str(k) ' of ' int2str(nfiles)])
        fName = mFiles(fNum).name;
        MeasurementsToH5(fName);
    end
end






