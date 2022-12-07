function TrackWhiskers(sessionDir,whiskingParams,splitUp)

if nargin<1; sessionDir=fileparts(cd); end
if nargin<2
    whiskingParams = jsondecode(fileread(fullfile(cd,'whiskerpad.json')));
    if numel(whiskingParams)>1; splitUp='Yes'; end
end

ext = '.mp4';
ignoreExt = '.measurements';
for wpNum=1:numel(whiskingParams)
    include_files = arrayfun(@(x) x.name(1:(end-length(ext))),...
        dir([sessionDir filesep 'WhiskerTracking' filesep '*' ext]),'UniformOutput',false);
    % Return list of files that are already tracked
    ignore_files = arrayfun(@(x) x.name(1:(end-length(ignoreExt))),...
        dir([sessionDir filesep 'WhiskerTracking' filesep '*' ignoreExt]),'UniformOutput',false);
    switch splitUp
        case 'Yes'
            switch whiskingParams(wpNum).FaceSideInImage
                case 'right'
                    keepLabel = 'Left';
                case 'left'
                    keepLabel = 'Right';
            end
            keepFile=logical(cellfun(@(fName) contains(fName,keepLabel,...
                'IgnoreCase',true), include_files));
        case 'No'
            keepFile = true(size(include_files));
    end
    inclusionIndex = ~ismember(include_files,ignore_files) & keepFile;
    include_files = include_files(inclusionIndex);

    % initialize parameters
    num_whiskers = 3; %-1 %10;

    % set pixel dimension
    if numel(whiskingParams)>1 %large FOV covering both sides of the head
        px2mm = 0.1;
    else
        px2mm = 0.05; %normal close up view of one side of the head
    end

    % set WP location horizontal (may be vertical array if loaded from file)
    if size(whiskingParams(wpNum).Location,1)>1; whiskingParams(wpNum).Location=transpose(whiskingParams(wpNum).Location); end
    
    % process all files
    TraceMeasureClassify(fullfile(sessionDir, 'WhiskerTracking'),'ext',ext,...
        'include_files',include_files,'side',whiskingParams(wpNum).FaceSideInImage,...
        'face_x_y',whiskingParams(wpNum).Location,'px2mm',px2mm,'num_whiskers',num_whiskers);

end