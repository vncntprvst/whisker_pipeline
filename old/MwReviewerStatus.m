function varargout = MwReviewerStatus(varargin)
% MWREVIEWERSTATUS MATLAB code for MwReviewerStatus.fig
%      MWREVIEWERSTATUS, by itself, creates a new MWREVIEWERSTATUS or raises the existing
%      singleton*.
%
%      H = MWREVIEWERSTATUS returns the handle to a new MWREVIEWERSTATUS or the handle to
%      the existing singleton*.
%
%      MWREVIEWERSTATUS('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MWREVIEWERSTATUS.M with the given input arguments.
%
%      MWREVIEWERSTATUS('Property','Value',...) creates a new MWREVIEWERSTATUS or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MwReviewerStatus_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MwReviewerStatus_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help MwReviewerStatus

% Last Modified by GUIDE v2.5 02-Jul-2015 17:37:12

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @MwReviewerStatus_OpeningFcn, ...
                   'gui_OutputFcn',  @MwReviewerStatus_OutputFcn, ...
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


% --- Executes just before MwReviewerStatus is made visible.
function MwReviewerStatus_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to MwReviewerStatus (see VARARGIN)

% Choose default command line output for MwReviewerStatus
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes MwReviewerStatus wait for user response (see UIRESUME)
% uiwait(handles.figure1);

vm = getappdata(varargin{1}, 'vm');
[ tableContent, columnName ] = vm.GetPipressTable();
set(handles.statusTable, 'ColumnName', columnName);
set(handles.statusTable, 'Data', tableContent);



% --- Outputs from this function are returned to the command line.
function varargout = MwReviewerStatus_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
