
whisk_filename = 'sc014_0315_001_right_00004000.whiskers';
measurements_file =  'sc014_0315_001_right_00004000.measurements';

measurements = Whisker.mexLoadMeasurements(measurements_file);

mfield=fieldnames(measurements);
for fnum=1:numel(mfield)
    class(measurements(1).(mfield{fnum}))
end

% 'fid'       'int32'
% 'wid'       'int32'
% 'label'     'int32'
% 'face_x'    'int32'
% 'face_y'    'int32'
% 'length'    'double'
% 'score'     'double'
% 'angle'     'double'
% 'curvature' 'double'
% 'follicle_x''double'
% 'follicle_y''double'
% 'tip_x'     'double'
% 'tip_y'     'double'
