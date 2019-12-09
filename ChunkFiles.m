function endNum = ChunkFiles(fn,id,startNum,outputLoc,videoFrameRate,sweepLengthInSec)

    % Get metadata from video (video time may not match real time)
    vid = VideoReader(fn);
    fps = vid.FrameRate;
    duration = vid.Duration;
    durationInFrames = fps*duration;
    
    % Calculate number of videos to split
    sweepLengthInFrames = sweepLengthInSec*videoFrameRate;
    numChunks = floor(durationInFrames/sweepLengthInFrames);
    
    % Match to real time
    sweepLengthInSec = sweepLengthInSec*(videoFrameRate/fps);

    startTimeInSec = 0;
    hrsStart = zeros(1,numChunks); 
    minStart = zeros(1,numChunks); 
    secStart = zeros(1,numChunks); 
    msStart = zeros(1,numChunks);
    
    hrsEnd = zeros(1,numChunks); 
    minEnd = zeros(1,numChunks); 
    secEnd = zeros(1,numChunks); 
    msEnd = zeros(1,numChunks);
    
    for t = 1:numChunks   
        timeStart = startTimeInSec;
        timeEnd = startTimeInSec + sweepLengthInSec;
        
        hrsStart(t) = floor(timeStart/3600);
        timeStart = timeStart - hrsStart(t)*3600;
        minStart(t) = floor(timeStart/60);
        timeStart = timeStart - minStart(t)*60;
        secStart(t) = floor(timeStart);
        timeStart = timeStart - secStart(t);
        msStart(t) = floor(timeStart*1000);
        
        hrsEnd(t) = floor(timeEnd/3600);
        timeEnd = timeEnd - hrsEnd(t)*3600;
        minEnd(t) = floor(timeEnd/60);
        timeEnd = timeEnd - minEnd(t)*60;
        secEnd(t) = floor(timeEnd);
        timeEnd = timeEnd - secEnd(t);
        msEnd(t) = floor(timeEnd*1000);
        
        startTimeInSec = startTimeInSec + sweepLengthInSec;
    end
    
    for t = 1%:numChunks
        trialNum = startNum + t - 1;
        outputName = [id '_trialNum' num2str(trialNum)];        
        startTime = [num2str(hrsStart(t)) ':'...
            num2str(minStart(t)) ':'...
            num2str(secStart(t)) '.'...
            num2str(msStart(t))];
        endTime = [num2str(hrsEnd(t)) ':' ...
            num2str(minEnd(t)) ':' ...
            num2str(secEnd(t)) '.' ...
            num2str(msEnd(t))];
        
        cmd = ['-y -i ' fn ' -ss ' startTime ' -to ' endTime ...
        ' -c:v copy -c:a copy ' outputLoc outputName '.mp4' ' -async 1 ' ...
        ' -hide_banner -loglevel panic'];
        disp(cmd);
        ffmpegexec(cmd);
    end
    
    endNum = startNum + numChunks - 1;

end