function noseLoc=GetNoseTipCoordinates(videoDirectory,videoFileName)

% videoDirectory = 'D:\Vincent\NWB\ExampleDatasets\Vincent\Ephys_Behavior\whisker_asym\sc007\sc007_1216\WhiskerTracking\';
% videoFileName = 'test.mp4';

BonsaiWFPath=fullfile(fileparts(mfilename('fullpath')),'VideoOp');

callFlags= [' -p:Path.Directory=' fullfile([videoDirectory filesep])...
    ' -p:Path.VideoFileName=' videoFileName...
    ' --start --noeditor'];

BonsaiWFPath=fullfile(BonsaiWFPath, 'GetMidline.bonsai');
sysCall=['Bonsai ' BonsaiWFPath callFlags];
disp(sysCall); system(sysCall);

[~,csvFn]=fileparts(videoFileName);
noseLoc=readmatrix(fullfile(videoDirectory, [csvFn '_NoseTipCoord.csv']));