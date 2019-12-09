function varargout = MwReviewer(varargin)
% MWREVIEWER MATLAB code for MwReviewer.fig
%      MWREVIEWER, by itself, creates a new MWREVIEWER or raises the existing
%      singleton*.
%
%      H = MWREVIEWER returns the handle to a new MWREVIEWER or the handle to
%      the existing singleton*.
%
%      MWREVIEWER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MWREVIEWER.M with the given input arguments.
%
%      MWREVIEWER('Property','Value',...) creates a new MWREVIEWER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MwReviewer_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MwReviewer_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MwReviewer

% Last Modified by GUIDE v2.5 26-Sep-2015 14:07:38

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MwReviewer_OpeningFcn, ...
                   'gui_OutputFcn',  @MwReviewer_OutputFcn, ...
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
% --- Executes just before MwReviewer is made visible.

function MwReviewer_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MwReviewer (see VARARGIN)

% Choose default command line output for MwReviewer
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MwReviewer wait for user response (see UIRESUME)
% uiwait(handles.figure1);

Initialize(handles);
% --- Outputs from this function are returned to the command line.

function varargout = MwReviewer_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in savePipressButton.
function savePipressButton_Callback(hObject, eventdata, handles)
% hObject    handle to savePipressButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
SavePipress(handles);

% --- Executes on button press in loadPipressButton.
function loadPipressButton_Callback(hObject, eventdata, handles)
% hObject    handle to loadPipressButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
LoadPipress(handles);

% --- Executes on button press in statusTableButton.
function statusTableButton_Callback(hObject, eventdata, handles)
% hObject    handle to statusTableButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
MwReviewerStatus(handles.output);

% --- Executes when selected cell(s) is changed in pipressTable.
function pipressTable_CellSelectionCallback(hObject, eventdata, handles)
% hObject    handle to pipressTable (see GCBO)
% eventdata  structure with the following fields (see UITABLE)
%	Indices: row and column indices of the cell(s) currently selecteds
% handles    structure with handles and user data (see GUIDATA)
%
% Interruptible property set to 'off' and BusyAction property set to
% 'cancel' to prevent callback barrage
TrialSelectionChange(eventdata, handles);

% --- Executes on key release with focus on figure1 or any of its controls.
function figure1_WindowKeyReleaseFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was released, in lower case
%	Character: character interpretation of the key(s) that was released
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) released
% handles    structure with handles and user data (see GUIDATA)
%
% Interruptible property set to 'off' and BusyAction property set to
% 'cancel' to prevent callback barrage
ShortKey(eventdata, handles);

% --- Executes during object creation, after setting all properties.
function curatorEdit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to curatorEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function curatorEdit_Callback(hObject, eventdata, handles)
% hObject    handle to curatorEdit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of curatorEdit as text
%        str2double(get(hObject,'String')) returns contents of curatorEdit as a double
CuratorNameChange(handles);

% --- Executes on button press in poleCheckbox.
function poleCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to poleCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.rvBar = get(hObject, 'Value');
setappdata(handles.output, 'vm', vm);
RefreshUI(handles, false);

% --- Executes on button press in contactCheckbox.
function contactCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to contactCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.rvContact = get(hObject, 'Value');
setappdata(handles.output, 'vm', vm);

% --- Executes on button press in facemaskCheckbox.
function facemaskCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to facemaskCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.profileFacemasks = get(hObject, 'Value');
setappdata(handles.output, 'vm', vm);

% --- Executes on selection change in barErrPopupmenu.
function barErrPopupmenu_Callback(hObject, eventdata, handles)
% hObject    handle to barErrPopupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns barErrPopupmenu contents as cell array
%        contents{get(hObject,'Value')} returns selected item from barErrPopupmenu

% --- Executes during object creation, after setting all properties.
function barErrPopupmenu_CreateFcn(hObject, eventdata, handles)
% hObject    handle to barErrPopupmenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in barLabelButton.
function barLabelButton_Callback(hObject, eventdata, handles)
% hObject    handle to barLabelButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
SetPoleLabel(handles);

% --- Executes on button press in martinyButton.
function martinyButton_Callback(hObject, eventdata, handles)
% hObject    handle to martinyButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
ChangeUiState(handles, 'off');
vm.ShowMartiny(get(handles.martinyCheckbox, 'Value'));
ChangeUiState(handles, 'on');

% --- Executes on button press in martinyCheckbox.
function martinyCheckbox_Callback(hObject, eventdata, handles)
% hObject    handle to martinyCheckbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of martinyCheckbox

% --- Executes on button press in rainbowButton.
function rainbowButton_Callback(hObject, eventdata, handles)
% hObject    handle to rainbowButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
vm = getappdata(handles.output, 'vm');
vm.ShowRainbowFacemask();



% UI
function Initialize(handles)
% Initializes view-model
vm = MwReviewerVM();

setappdata(handles.output, 'vm', vm);
% Initializes UI
RefreshUI(handles);

function RefreshUI(handles, switchTrial)
if nargin < 2
    switchTrial = true;
end
if isappdata(handles.output, 'vm')
    vm = getappdata(handles.output, 'vm');
    if ~vm.IsValid()
        ChangeUiState(handles, 'off');
        set(handles.frameAxes, 'Visible', 'off');
    else
        try
            % Refreshes selections
            set(handles.poleCheckbox, 'Value', vm.rvBar);
            set(handles.contactCheckbox, 'Value', vm.rvContact);
            set(handles.facemaskCheckbox, 'Value', vm.profileFacemasks);
            ChangeUiState(handles, 'on');
            
            % Refreshes display
            if switchTrial
                set(handles.pipressTable, 'Data', vm.GetTrialNamePipress());        % update content
                SetSelectedCell(handles, vm.GetTrialIndex(), 1);                    % restore selection
                axes(handles.frameAxes);
                vm.ShowMarkedImage();
                hold on
                vm.ShowFacemask();
                hold off
                vm.ShowContactProfile();
                axes(handles.frameAxes);
            end
            set(handles.doneText, 'String', [ 'Has been ' vm.GetBarStatus() ]);
            if vm.rvBar
                set(handles.todoText, 'String', [ 'To be ' vm.rvBarLabel ]);
            else
                set(handles.todoText, 'String', 'Not curating');
            end
        catch
            ChangeUiState(handles, 'off');
            disp('Error during update ...');
        end
    end
end

function ChangeUiState(handles, state)
set(handles.poleCheckbox, 'Enable', state);
set(handles.contactCheckbox, 'Enable', state);
set(handles.facemaskCheckbox, 'Enable', state);

set(handles.barLabelButton, 'Enable', state);
set(handles.barErrPopupmenu, 'Enable', state);
set(handles.martinyButton, 'Enable', state);
set(handles.martinyCheckbox, 'Enable', state);
set(handles.rainbowButton, 'Enable', state);

set(handles.statusTableButton, 'Enable', state);
set(handles.savePipressButton, 'Enable', state);
set(handles.pipressTable, 'Enable', state);

set(handles.todoText, 'Visible', state);
set(handles.doneText, 'Visible', state);

function SetSelectedCell(handles, r, c)
% achieving this by modifying properties of Java UITable control
jScroll = findjobj(handles.pipressTable);
jTable = jScroll.getViewport.getView;
jTable.changeSelection(r-1, c-1, false, false);

function selected = GetSelectedItem(popupmenuHandle)
list = cellstr(get(popupmenuHandle, 'String'));
idx = get(popupmenuHandle, 'Value');
selected = list{idx};



% Called when the content in curator name editbox is changed
function CuratorNameChange(handles)
vm = getappdata(handles.output, 'vm');
updateUI = ~vm.IsValid();
vm.curator = get(handles.curatorEdit,'String');
setappdata(handles.output, 'vm', vm);
if updateUI && vm.IsValid()
    RefreshUI(handles);
end

% Handles the global key press
function ShortKey(eventdata, handles)
vm = getappdata(handles.output, 'vm');
if ~isempty(vm.pipressObj.pipress)
    updateUI = false;
    
    % Handles key press
    switch eventdata.Key
        case 'f2'
            updateUI = vm.LastTrial();
        case 'f3'
            updateUI = vm.NextTrial();
        case 'f4'
            SetPolePos(handles);
    end
    axes(handles.frameAxes);
    
    % Updates UI
    if updateUI
        RefreshUI(handles);
        set(handles.barLabelButton, 'Value', false);
    end
end

% Called when the selection in pipressTable is changed
function TrialSelectionChange(eventdata, handles)
if ~isempty(eventdata.Indices)
    vm = getappdata(handles.output, 'vm');
    newTrialIndex = eventdata.Indices(1);
    if vm.SwitchTrial(newTrialIndex)
        setappdata(handles.output, 'vm', vm);
        RefreshUI(handles);
        set(handles.barLabelButton, 'Value', false);
    end
end

% To change bar position
function SetPolePos(handles)
vm = getappdata(handles.output, 'vm');
if vm.rvBar
    vm.SetPolePos();
    RefreshUI(handles, false);
end
setappdata(handles.output, 'vm', vm);

function SetPoleLabel(handles)
vm = getappdata(handles.output, 'vm');
vm.SetPoleLabel(GetSelectedItem(handles.barErrPopupmenu));
setappdata(handles.output, 'vm', vm);
RefreshUI(handles, false);


% Load and Save
function LoadPipress(handles)
vm = getappdata(handles.output, 'vm');
if vm.LoadPipress()
    setappdata(handles.output, 'vm', vm);
    RefreshUI(handles);
end

function SavePipress(handles)
vm = getappdata(handles.output, 'vm');
vm.SavePipress();

