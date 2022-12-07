function TraceMeasureClassify(d,varargin)
% based on Janelia whisker tracking pipeline

p = inputParser;

p.addRequired('d', @ischar);
p.addParameter('include_files', {}, @(x) all(cellfun(@ischar,x)));
p.addParameter('ignore_files', {}, @(x) all(cellfun(@ischar,x)));
p.addParameter('face_x_y', [340 450], @isnumeric);
p.addParameter('num_whiskers', 1, @isnumeric);
p.addParameter('ext','.mp4',@ischar);
p.addParameter('side','',@ischar);
p.addParameter('px2mm',0.1, @isnumeric);

p.parse(d,varargin{:});

disp 'List of all arguments:'
disp(p.Results)

if ~strcmp(d(end), filesep)
    d = [d filesep];
end

currentDir = pwd;
cd(d)

vfNames = arrayfun(@(x) x.name(1:(end-4)), dir([d '*.mp4']),'UniformOutput',false);

if ~isempty(p.Results.include_files) % Make sure files are found. If not, ignored.
    ind = ismember(p.Results.include_files,vfNames);
    vfNames = p.Results.include_files(ind);
    if sum(ind) ~= numel(ind)
        disp('The following files in ''include_files'' were not found in directory ''d'' and will be skipped:')
        disp(p.Results.include_files(~ind))
    end
end

if ~isempty(p.Results.ignore_files)
    ind = ~ismember(vfNames,p.Results.ignore_files);
    vfNames = vfNames(ind);
end

inBoth = intersect(p.Results.include_files,p.Results.ignore_files);
if ~isempty(inBoth)
    disp('The following files were given in BOTH ''include_files'' and ''ignore files'' and will be ignored:')
    disp(inBoth)
end

nfiles = length(vfNames);

if ~isempty(vfNames)
    
    parfor k=1:nfiles
        fn = vfNames{k};
        disp(['Processing file '  fn ', ' int2str(k) ' of ' int2str(nfiles)])
        % Trace
        syscall = ['trace ' fn '.mp4 ' fn '.whiskers']; disp(syscall); system(syscall);
        % Measure
        syscall = ['measure --face ' num2str(p.Results.face_x_y) ' x  '...
            fn '.whiskers ' fn '.measurements']; disp(syscall); system(syscall);
        % Classify
        syscall = ['classify ' fn '.measurements ' fn '.measurements '...
            num2str(p.Results.face_x_y) ' x --px2mm 0.032 -n '...
            num2str(p.Results.num_whiskers) ' --limit2.0:50.0']; disp(syscall); system(syscall); 
    end
end

cd(currentDir)




