function DockerTrace(videoFiles,exportFolder)

if ~exist("exportFolder","var"); exportFolder='WhiskerTracking';end

[~,procNum]=system('wmic cpu get NumberOfCores,NumberOfLogicalProcessors');
procNum=regexp(procNum,'\d+','match'); procNum=procNum{end};

for fileNum=1:numel(videoFiles)
    videoFileName=videoFiles(fileNum).name;
    videoDirectory=videoFiles(fileNum).folder;

    cd(videoDirectory)
    if ~exist('WhiskerTracking','dir'); mkdir WhiskerTracking; end

    sysCall=[...
        'docker run --rm -v ' videoDirectory ':/data -t wanglabneuro/whisk ' ...
        'python -c "import WhiskiWrap; from WhiskiWrap import FFmpegReader; '...
        'WhiskiWrap.interleaved_read_trace_and_measure(FFmpegReader(''/data/' videoFileName '''),' ...
        '''' exportFolder ''', chunk_name_pattern=''' videoFileName(1:end-4) '%08d.tif'',' ... 
        ' h5_filename=""' videoFileName(1:end-4) '.hdf5""",n_trace_processes=' procNum ')""'];

    disp(sysCall);
    system(sysCall);

end
