d = 'D:\UserData\Kyle\PrV\WX010\workspace\'; face_x_y = [490 470]; num_whiskers = 15; %   Running, Needs compression, transfer
cd(d)

ext = '.mp4';
ignoreExt = '.measurements';
include_files = arrayfun(@(x) x.name(1:(end-length(ext))), dir([d '*' ext]),'UniformOutput',false);
ignore_files = arrayfun(@(x) x.name(1:(end-length(ignoreExt))), dir([d '*' ignoreExt]),'UniformOutput',false); % Returns list of files that are already tracked
c = setdiff(include_files,ignore_files);
size(include_files)
size(ignore_files)
size(c)
include_files = c;

tic
Whisker.makeAllDirectory_Tracking(d,'ext',ext,'include_files',include_files,'face_x_y',face_x_y,'num_whiskers',num_whiskers);
toc

%% ------------------------------------------------------------------------------

d = 'D:\WhiskerPipeline\Jinghao\KS0271A\'; face_x_y = [360 460]; num_whiskers = 15; %   Running, Needs compression, transfer
cd(d)

ext = '.tif';
include_files = arrayfun(@(x) x.name(1:(end-4)), dir([d '*' ext]),'UniformOutput',false);
ignore_files = arrayfun(@(x) x.name(1:(end-13)), dir([d '*.measurements']),'UniformOutput',false); % Returns list of .tif files that are already tracked
c = setdiff(include_files,ignore_files);
size(include_files)
size(ignore_files)
size(c)
include_files = c;

tic
Whisker.makeAllDirectory_Tracking(d,'ext',ext,'include_files',include_files,'face_x_y',face_x_y,'num_whiskers',num_whiskers);
toc

%% ------------------------------------------------------------------------------

d = 'D:\WhiskerPipeline\Jinghao\KS0282A\'; face_x_y = [340 440]; num_whiskers = 15; %   Running, Needs compression, transfer
cd(d)

ext = '.tif';
include_files = arrayfun(@(x) x.name(1:(end-4)), dir([d '*' ext]),'UniformOutput',false);
ignore_files = arrayfun(@(x) x.name(1:(end-13)), dir([d '*.measurements']),'UniformOutput',false); % Returns list of .tif files that are already tracked
c = setdiff(include_files,ignore_files);
size(include_files)
size(ignore_files)
size(c)
include_files = c;

tic
Whisker.makeAllDirectory_Tracking(d,'ext',ext,'include_files',include_files,'face_x_y',face_x_y,'num_whiskers',num_whiskers);
toc