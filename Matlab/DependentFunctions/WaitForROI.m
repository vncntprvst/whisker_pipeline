function WaitForROI(hROI)
% Let user draw and modify ROI before proceeding
% from: https://www.mathworks.com/help/images/use-wait-function-after-drawing-roi-example.html

% Listen for mouse clicks on the ROI
l = addlistener(hROI,'ROIClicked',@clickCallback);

% Block program execution
uiwait;

% Remove listener
delete(l);

end

function clickCallback(~,evt)

if strcmp(evt.SelectionType,'double')
    uiresume;
end

end