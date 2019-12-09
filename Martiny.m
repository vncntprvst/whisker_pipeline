function varargout = Martiny(varargin)
% MARTINY MATLAB code for Martiny.fig
%      MARTINY, by itself, creates a new MARTINY or raises the existing
%      singleton*.
%
%      H = MARTINY returns the handle to a new MARTINY or the handle to
%      the existing singleton*.
%
%      MARTINY('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MARTINY.M with the given input arguments.
%
%      MARTINY('Property','Value',...) creates a new MARTINY or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Martiny_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Martiny_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help Martiny

% Last Modified by GUIDE v2.5 15-Sep-2015 09:01:48

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Martiny_OpeningFcn, ...
                   'gui_OutputFcn',  @Martiny_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Martiny is made visible.
function Martiny_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Martiny (see VARARGIN)

% Choose default command line output for Martiny
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes Martiny wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% Initializes view-model
p = inputParser();
p.addOptional('loadRawTrajectory', true);
p.addOptional('loadPhysics', true);
p.addOptional('loadFacemasks', true);
p.addParameter('tifPath', []);

p.parse(varargin{:});
set(handles.rawTrajCheckbox, 'Value', p.Results.loadRawTrajectory);
set(handles.fitTrajCheckbox, 'Value', p.Results.loadPhysics);
set(handles.facemaskCheckbox, 'Value', p.Results.loadFacemasks);
NewViewModel(handles, p.Results.tifPath);


% --- Outputs from this function are returned to the command line.
function varargout = Martiny_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on key press with focus on figure1 or any of its controls.
function figure1_WindowKeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)
GlobalKeyPress(handles, eventdata);


% --- Executes on scroll wheel click while the figure is in focus.
function figure1_WindowScrollWheelFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	VerticalScrollCount: signed integer indicating direction and number of clicks
%	VerticalScrollAmount: number of lines scrolled for each click
% handles    structure with handles and user data (see GUIDATA)
GlobalKeyPress(handles, eventdata);


% --- Executes on key release with focus on figure1 or any of its controls.
function figure1_WindowKeyReleaseFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was released, in lower case
%	Character: character interpretation of the key(s) that was released
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) released
% handles    structure with handles and user data (see GUIDATA)
GlobalKeyRelease(handles, eventdata);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
try
    if isappdata(handles.output, 'vm')
        vm = getappdata(handles.output, 'vm');
        delete(vm);
    end
catch
end

% Hint: delete(hObject) closes the figure
delete(hObject);


function frameEdit_Callback(hObject, eventdata, handles)
% hObject    handle to frameEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of frameEdit as text
%        str2double(get(hObject,'String')) returns contents of frameEdit as a double
vm = getappdata(handles.output, 'vm');
if vm.SetCurrentFrame(str2double(get(hObject, 'String')))
    setappdata(handles.output, 'vm', vm);
    RefreshUI(handles);
end
set(handles.frameEdit, 'String', num2str(vm.currentFrame));


% --- Executes during object creation, after setting all properties.
function frameEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to frameEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in loadButton.
function loadButton_Callback(hObject, eventdata, handles)
% hObject    handle to loadButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
NewViewModel(handles);


% --- Executes on button press in rawTrajCheckbox.
function rawTrajCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to rawTrajCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rawTrajCheckbox
vm = getappdata(handles.output, 'vm');
vm.showRawTrajectory = get(hObject, 'Value');
setappdata(handles.output, 'vm', vm);


% --- Executes on button press in fitTrajCheckbox.
function fitTrajCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to fitTrajCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fitTrajCheckbox
vm = getappdata(handles.output, 'vm');
vm.showFittedTrajectory = get(hObject, 'Value');
setappdata(handles.output, 'vm', vm);


% --- Executes on button press in facemaskCheckbox.
function facemaskCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to facemaskCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of facemaskCheckbox
vm = getappdata(handles.output, 'vm');
vm.showFacemask = get(hObject, 'Value');
setappdata(handles.output, 'vm', vm);


% --- Executes on button press in profileButton.
function profileButton_Callback(hObject, eventdata, handles)
% hObject    handle to profileButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.ShowProfile();


function NewViewModel(handles, tifPath)
if nargin < 2
    tifPath = [];
end

% Delete previous view-model
if isappdata(handles.output, 'vm')
    vm = getappdata(handles.output, 'vm');
    delete(vm);
end

% Initialize new view-model
vm = MartinyVM( ...
    'loadRawTrajectory', get(handles.rawTrajCheckbox, 'Value'), ...
    'loadPhysics', get(handles.fitTrajCheckbox, 'Value'), ...
    'loadFacemask', get(handles.facemaskCheckbox, 'Value'), ...
    'tifPath', tifPath);
setappdata(handles.output, 'vm', vm);

% Update UI
set(handles.figure1, 'Name', vm.tifName);
RefreshUI(handles);

axes(handles.imgAxes);
axis off;


function RefreshUI(handles)
vm = getappdata(handles.output, 'vm');

set(handles.rawTrajCheckbox, 'Value', vm.showRawTrajectory);
set(handles.fitTrajCheckbox, 'Value', vm.showFittedTrajectory);
set(handles.facemaskCheckbox, 'Value', vm.showFacemask);
set(handles.frameEdit, 'String', num2str(vm.currentFrame));

if vm.hasImage
    vm.ShowFrame(handles.imgAxes);
    vm.ShowTrajectory(handles.imgAxes);
    vm.ShowFacemask(handles.imgAxes);
    vm.ShowCurrentFrameLabel();
end


% Handles the global key press
function GlobalKeyPress(handles, eventdata)
if isappdata(handles.output, 'vm')
    vm = getappdata(handles.output, 'vm');
    updateUI = false;
    
    % Keyboard inputs
    if isfield(eventdata, 'Key') || isa(eventdata, 'matlab.ui.eventdata.KeyData')
        % Handles key press
        if any(strcmp(eventdata.Modifier, 'control'))
            if any(strcmp(eventdata.Modifier, 'shift'))
                frChange = 50;
            else
                frChange = 10;
            end
        else
            frChange = 1;
        end
        
        switch eventdata.Key
            case 'rightarrow'
                updateUI = vm.SetCurrentFrame(vm.currentFrame + frChange);
            case 'leftarrow'
                updateUI = vm.SetCurrentFrame(vm.currentFrame - frChange);
        end
    % Mouse scrolling input
    else
        signChange = sign(eventdata.VerticalScrollCount);
        frChange = min(abs(eventdata.VerticalScrollCount), 3);
        updateUI = vm.SetCurrentFrame(vm.currentFrame + signChange*frChange);
    end
    
    % Updates UI
    if updateUI
        setappdata(handles.output, 'vm', vm);
        RefreshUI(handles);
    end
    pause(0.02);
end


% Handles the global key release
function GlobalKeyRelease(handles, eventdata)
if isappdata(handles.output, 'vm')
    vm = getappdata(handles.output, 'vm');
    
    % Handles key press
    switch eventdata.Key
        case 'f4'
            vm.ClearContact();
        case 'f5'
            vm.SetContact();
        case 'f12'
            vm.SaveFigure(handles.imgAxes);
        case 's'
            if any(strcmp('control', eventdata.Modifier))
                vm.SaveContactCuration();
            end
        case { '1', '2' }
            if any(strcmp('control', eventdata.Modifier))
                pos = get(handles.figure1, 'Position');
                anchorY = pos(2) + pos(4);
                pos(3:4) = [ 640 510 ] * str2double(eventdata.Key);
                pos(2) = anchorY - pos(4);
                set(handles.figure1, 'Position', pos);
            end
    end
    pause(0.02);
end
