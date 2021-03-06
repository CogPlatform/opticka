% ========================================================================
%> @brief baseStimulus is the superclass for all opticka stimulus objects
%>
%> Superclass providing basic structure for all stimulus classes. This is a dynamic properties
%> descendant, allowing for the temporary run variables used, which get appended "name"Out, i.e.
%> speed is duplicated to a dymanic property called speedOut; it is the dynamic propertiy which is
%> used during runtime, and whose values are converted from definition units like degrees to pixel
%> values that PTB uses. The transient copies are generated on setup and removed on reset.
%>
% ========================================================================
classdef baseStimulus < optickaCore & dynamicprops
	
	properties (Abstract = true, SetAccess = protected)
		%> the stimulus family (grating, dots etc.)
		family char
	end
	
	properties
		%> X Position +- in degrees relative to screen center (0,0)
		xPosition double = 0
		%> Y Position +- in degrees relative to screen center (0,0)
		yPosition double = 0
		%> Size in degrees
		size double = 4
		%> Colour as a 0-1 range RGB or RGBA
		colour double = [1 1 1 1]
		%> Alpha as a 0-1 range, this gets added to the RGB colour
		alpha double = 1
		%> Do we print details to the commandline?
		verbose = false
		%> For moving stimuli do we start "before" our initial position? THis allows you to
		%> center a stimulus at a screen location, but then drift it across that location, so
		%> if xyPosition is 0,0 and startPosition is -2 then the stimulus will start at -2 drifing
		%> towards 0.
		startPosition double = 0
		%> speed in degs/s
		speed double = 0
		%> angle in degrees
		angle double = 0
		%> delay time to display relative to stimulus onset, can set upper and lower range
		%> for random interval. This allows for a goup of stimuli some to be delayed relative
		%> to others for a global stimulus onset time.
		delayTime double = 0
		%> time to turn stimulus off, relative to stimulus onset
		offTime double = Inf
		%> override X and Y position with mouse input? Useful for RF mapping
		mouseOverride logical = false
		%> true or false, whether to draw() this object
		isVisible logical = true
		%> show the position on the Eyelink display?
		showOnTracker logical = true
	end
	
	properties (SetAccess = protected, GetAccess = public)
		%> Our source screen rectangle position in PTB format
		dstRect double = []
		%> Our screen rectangle position in PTB format, update during animations
		mvRect double = []
		%> computed X position for stimuli that don't use rects
		xOut double = []
		%> computed Y position for stimuli that don't use rects
		yOut double = []
		%> tick updates +1 on each draw, resets on each update
		tick double = 0
		%> pixels per degree (normally inhereted from screenManager)
		ppd double = 36
	end
	
	properties (SetAccess = protected, GetAccess = public, Transient = true)
		%> Our texture pointer for texture-based stimuli
		texture
		%> handles for the GUI
		handles
		%> our screen manager
		sM
	end
	
	properties (Dependent = true, SetAccess = private, GetAccess = public)
		%> What our per-frame motion delta is
		delta double
		%> X update which is computed from our speed and angle
		dX double
		%> X update which is computed from our speed and angle
		dY double
	end
	
	properties (SetAccess = protected, GetAccess = protected)
		%> is mouse position within screen co-ordinates?
		mouseValid logical = false
		%> mouse X position
		mouseX = 0
		%> mouse Y position
		mouseY = 0
		%> delay ticks to wait until display
		delayTicks = 0
		%> ticks before stimulus turns off
		offTicks = Inf
		%>are we setting up?
		inSetup logical = false
		%> delta cache
		delta_
		%> dX cache
		dX_
		%> dY cache
		dY_
		%> Which properties to ignore to clone when making transient copies in
		%> the setup method
		ignorePropertiesBase char = 'handles|ppd|sM|name|comment|fullName|family|type|dX|dY|delta|verbose|texture|dstRect|mvRect|xOut|yOut|isVisible|dateStamp|paths|uuid|tick';
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> properties allowed to be passed on construction
		allowedProperties char = 'xPosition|yPosition|size|colour|verbose|alpha|startPosition|angle|speed|delayTime|mouseOverride|isVisible'
	end
	
	events
		%> triggered when reading from a UI panel,
		readPanelUpdate
	end
	
	%=======================================================================
	methods %------------------PUBLIC METHODS
		%=======================================================================
		
		% ===================================================================
		%> @brief Class constructor
		%>
		%> @param varargin are passed as a structure / cell of properties which is
		%> parsed.
		%> @return instance of class.
		% ===================================================================
		function me = baseStimulus(varargin)
			if nargin == 0; varargin.name = 'baseStimulus'; end
			me=me@optickaCore(varargin); %superclass constructor
			
			if nargin > 0; me.parseArgs(varargin,me.allowedProperties); end
			
			if isempty(me.sM) %add a default screenManager, overwritten on setup
				me.sM = screenManager('verbose',false,'name','default');
				me.ppd = me.sM.ppd;
			end
		end
		
		% ===================================================================
		%> @brief colour set method
		%> Allow 1 (R=G=B) 3 (RGB) or 4 (RGBA) value colour
		% ===================================================================
		function set.colour(me,value)
			len=length(value);
			switch len
				case {4,3}
					me.colour = [value(1:3) me.alpha]; %force our alpha to override
				case 1
					me.colour = [value value value me.alpha]; %construct RGBA
				otherwise
					if isa(me,'gaborStimulus') || isa(me,'gratingStimulus')
						me.colour = []; %return no colour to procedural gratings
					else
						me.colour = [1 1 1 me.alpha]; %return white for everything else
					end		
			end
			me.colour(me.colour<0)=0; me.colour(me.colour>1)=1;
		end
		
		% ===================================================================
		%> @brief alpha set method
		%> 
		% ===================================================================
		function set.alpha(me,value)
			if value<0; value=0;elseif value>1; value=1; end
			me.alpha = value;
			me.colour = me.colour(1:3); %force colour to be regenerated
			if isprop(me,'colour2')
				me.colour2 = me.colour2(1:3);
			end
		end
		
		% ===================================================================
		%> @brief delta Get method
		%> delta is the normalised number of pixels per frame to move a stimulus
		% ===================================================================
		function value = get.delta(me)
			if isempty(me.findprop('speedOut'))
				value = (me.speed * me.ppd) * me.sM.screenVals.ifi;
			else
				value = (me.speedOut * me.ppd) * me.sM.screenVals.ifi;
			end
		end
		
		% ===================================================================
		%> @brief dX Get method
		%> X position increment for a given delta and angle
		% ===================================================================
		function value = get.dX(me)
			if ~isempty(me.findprop('motionAngle'))
				if isempty(me.findprop('motionAngleOut'))
					[value,~]=me.updatePosition(me.delta,me.motionAngle);
				else
					[value,~]=me.updatePosition(me.delta,me.motionAngleOut);
				end
			else
				if isempty(me.findprop('angleOut'))
					[value,~]=me.updatePosition(me.delta,me.angle);
				else
					[value,~]=me.updatePosition(me.delta,me.angleOut);
				end
			end
		end
		
		% ===================================================================
		%> @brief dY Get method
		%> Y position increment for a given delta and angle
		% ===================================================================
		function value = get.dY(me)
			if ~isempty(me.findprop('motionAngle'))
				if isempty(me.findprop('motionAngleOut'))
					[~,value]=me.updatePosition(me.delta,me.motionAngle);
				else
					[~,value]=me.updatePosition(me.delta,me.motionAngleOut);
				end
			else
				if isempty(me.findprop('angleOut'))
					[~,value]=me.updatePosition(me.delta,me.angle);
				else
					[~,value]=me.updatePosition(me.delta,me.angleOut);
				end
			end
		end
		
		% ===================================================================
		%> @brief Method/function shorthand to set isVisible=true.
		%>
		% ===================================================================
		function show(me)
			me.isVisible = true;
		end
		
		% ===================================================================
		%> @brief Method/function shorthand to set isVisible=false.
		%>
		% ===================================================================
		function hide(me)
			me.isVisible = false;
		end
		
		% ===================================================================
		%> @brief reset the various tick counters for our stimulus
		%>
		% ===================================================================
		function resetTicks(me)
			global mouseTick %shared across all stimuli
			if max(me.delayTime) > 0 %delay display a number of frames 
				if length(me.delayTime) == 1
					me.delayTicks = round(me.delayTime/me.sM.screenVals.ifi);
				elseif length(me.delayTime) == 2
					time = randi([me.delayTime(1)*1000 me.delayTime(2)*1000])/1000;
					me.delayTicks = round(time/me.sM.screenVals.ifi);
				end
			else
				me.delayTicks = 0;
			end
			if min(me.offTime) < Inf %delay display a number of frames 
				if length(me.offTime) == 1
					me.offTicks = round(me.offTime/me.sM.screenVals.ifi);
				elseif length(me.offTime) == 2
					time = randi([me.offTime(1)*1000 me.offTime(2)*1000])/1000;
					me.offTicks = round(time/me.sM.screenVals.ifi);
				end
			else
				me.offTicks = Inf;
			end
			mouseTick = 1;
			if me.mouseOverride
				getMousePosition(me);
			end
			me.tick = 0; 
		end
		
		% ===================================================================
		%> @brief get mouse position
		%> we make sure this is only called once per animation tick to
		%> improve performance and ensure all stimuli that are following
		%> mouse position have consistent X and Y per frame update
		%> This sets mouseX and mouseY and mouseValid if mouse is within
		%> PTB screen (useful for mouse override positioning for stimuli)
		% ===================================================================
		function getMousePosition(me)
			global mouseTick
			me.mouseValid = false;
			if me.tick > mouseTick
				if isa(me.sM,'screenManager') && me.sM.isOpen
					[me.mouseX,me.mouseY] = GetMouse(me.sM.win);
					if me.mouseX <= me.sM.screenVals.width && me.mouseY <= me.sM.screenVals.height
						me.mouseValid = true;
					end
				else
					[me.mouseX,me.mouseY] = GetMouse;
				end
				mouseTick = me.tick; %set global so no other object with same tick number can call this again
			end
		end
		
		% ===================================================================
		%> @brief Run Stimulus in a window to preview
		%>
		% ===================================================================
		function run(me, benchmark, runtime, s, forceScreen, showVBL)
		% RUN stimulus: run(benchmark, runtime, s, forceScreen, showVBL)
			try
				warning off
				if ~exist('benchmark','var') || isempty(benchmark)
					benchmark=false;
				end
				if ~exist('runtime','var') || isempty(runtime)
					runtime = 2; %seconds to run
				end
				if ~exist('s','var') || ~isa(s,'screenManager')
					s = me.sM;
					s.blend = true; 
					s.disableSyncTests = true;
					s.visualDebug = true;
					s.bitDepth = '8bit';
				end
				if ~exist('forceScreen','var') || isempty(forceScreen); forceScreen = -1; end
				if ~exist('showVBL','var') || isempty(showVBL); showVBL = false; end

				oldscreen = s.screen;
				oldbitdepth = s.bitDepth;
				if forceScreen >= 0
					s.screen = forceScreen;
					if forceScreen == 0
						s.bitDepth = 'FloatingPoint32BitIfPossible';
					end
				end
				prepareScreen(s);
				
				oldwindowed = s.windowed;
				if benchmark
					s.windowed = false;
				elseif forceScreen > -1
					s.windowed = [0 0 s.screenVals.width/2 s.screenVals.height/2]; %middle of screen
				end
				
				if ~s.isOpen
					sv=open(s); %open PTB screen
				end
				setup(me,s); %setup our stimulus object
				
				Priority(MaxPriority(s.win)); %bump our priority to maximum allowed
				
				if ~strcmpi(me.type,'movie'); draw(me); end
				if s.visualDebug
					drawGrid(s); %draw +-5 degree dot grid
					drawScreenCenter(s); %centre spot
				end
				
				if benchmark
					Screen('DrawText', s.win, 'BENCHMARK: screen won''t update properly, see FPS on command window at end.', 5,5,[0 0 0]);
				else
					Screen('DrawText', s.win, 'Stim will be static for 2 seconds, then animated...', 5,5,[0 0 0]);
				end
				
				flip(s);
				WaitSecs('YieldSecs',2);
				nFrames = 0;
				notFinished = true;
				benchmarkFrames = sv.fps * runtime;
				vbl(1) = flip(s); startT = vbl(1);
				
				while notFinished
					nFrames = nFrames + 1;
					draw(me); %draw stimulus
					if ~benchmark&&s.visualDebug;drawGrid(s);end
					finishDrawing(s); %tell PTB/GPU to draw
 					animate(me); %animate stimulus, will be seen on next draw
					if benchmark
						Screen('Flip',s.win,0,2,2);
					else
						vbl(nFrames) = flip(s, vbl(end)); %flip the buffer
					end
					if benchmark
						notFinished =  nFrames <= benchmarkFrames;
					else
						notFinished = vbl(end) <= startT + runtime;
					end	
				end
				
				endT = flip(s);
				WaitSecs(0.5);
				if showVBL
					figure;
					plot(diff(vbl)*1e3);
					line([0 length(vbl-1)],[sv.ifi*1e3 sv.ifi*1e3]);
					title(sprintf('VBL Times, should be ~%.2f ms',sv.ifi*1e3));
					ylabel('Time (ms)')
					xlabel('Frames')
				end
				Priority(0); ShowCursor; ListenChar(0);
				reset(me); %reset our stimulus ready for use again
				close(s); %close screen
				s.screen = oldscreen;
				s.windowed = oldwindowed;
				s.bitDepth = oldbitdepth;
				fps = nFrames / (endT-startT);
				fprintf('\n\n======>>> <strong>SPEED</strong> (%i frames in %.2f secs) = <strong>%g</strong> fps <<<=======\n\n',nFrames, endT-startT, fps);
				clear fps benchmark runtime b bb i; %clear up a bit
				warning on
			catch ME
				warning on
				getReport(ME)
				Priority(0);
				if exist('s','var') && isa(s,'screenManager')
					close(s);
				end
				warning on
				clear fps benchmark runtime b bb i; %clear up a bit
				reset(me); %reset our stimulus ready for use again
				rethrow(ME)				
			end
		end
		
		% ===================================================================
		%> @brief make a GUI properties panel for this object
		%>
		% ===================================================================
		function handles = makePanel(me, parent)
			
			if ~isempty(me.handles) && isa(me.handles.root,'uiextras.BoxPanel') && ishandle(me.handles.root)
				fprintf('---> Panel already open for %s\n', me.fullName);
				return
			end
			
			if ~exist('parent','var')
				parent = figure('Tag','gFig',...
					'Name', [me.fullName 'Properties'], ...
					'CloseRequestFcn', @me.closePanel,...
					'MenuBar', 'none', ...
					'NumberTitle', 'off');
				figpos(1,[800 300]);
			end
			
			bgcolor = [0.91 0.91 0.91];
			bgcoloredit = [0.95 0.95 0.95];
			fsmall = 8;
			if ismac
				SansFont = 'avenir next';
				MonoFont = 'menlo';
			elseif ispc
				SansFont = 'calibri';
				MonoFont = 'consolas';
			else %linux
				SansFont = 'Liberation Sans'; %get(0,'defaultAxesFontName');
				MonoFont = 'Fira Code';
			end
			
			handles.parent = parent;
			handles.root = uiextras.BoxPanel('Parent',parent,...
				'Title',me.fullName,...
				'FontName',SansFont,...
				'FontSize',fsmall,...
				'FontWeight','normal',...
				'Padding',0,...
				'TitleColor',[0.8 0.78 0.76],...
				'BackgroundColor',bgcolor);
			handles.hbox = uiextras.HBox('Parent', handles.root,'Padding',1,'Spacing',1,'BackgroundColor',bgcolor);
			handles.grid1 = uiextras.Grid('Parent', handles.hbox,'Padding',1,'Spacing',1,'BackgroundColor',bgcolor);
			handles.grid2 = uiextras.Grid('Parent', handles.hbox,'Padding',1,'Spacing',1,'BackgroundColor',bgcolor);
			handles.grid3 = uiextras.VButtonBox('Parent',handles.hbox,'Padding',0,...
				'ButtonSize', [100 25],'Spacing',0,'BackgroundColor',bgcolor);
			set(handles.hbox,'Sizes', [-1 -1 102]);
			
			idx = {'handles.grid1','handles.grid2','handles.grid3'};
			
			pr = findAttributesandType(me,'SetAccess','public','notlogical');
			pr = sort(pr);
			lp = ceil(length(pr)/2);
			
			pr2 = findAttributesandType(me,'SetAccess','public','logical');
			pr2 = sort(pr2);
			lp2 = length(pr2);

			for i = 1:2
				for j = 1:lp
					cur = lp*(i-1)+j;
					if cur <= length(pr)
						val = me.(pr{cur});
						if ischar(val)
							if isprop(me,[pr{cur} 'List'])
								if strcmp(me.([pr{cur} 'List']),'filerequestor')
									val = regexprep(val,'\s+',' ');
									handles.([pr{cur} '_char']) = uicontrol('Style','edit',...
										'Parent',eval(idx{i}),...
										'Tag',['panel' pr{cur}],...
										'Callback',@me.readPanel,...
										'String',val,...
										'FontName',MonoFont,...
										'BackgroundColor',bgcoloredit);
								else
									txt=me.([pr{cur} 'List']);
									fidx = strcmpi(txt,me.(pr{cur}));
									fidx = find(fidx > 0);
									handles.([pr{cur} '_list']) = uicontrol('Style','popupmenu',...
										'Parent',eval(idx{i}),...
										'Tag',['panel' pr{cur} 'List'],...
										'String',txt,...
										'Callback',@me.readPanel,...
										'Value',fidx,...
										'BackgroundColor',bgcolor);
								end
							else
								val = regexprep(val,'\s+',' ');
								handles.([pr{cur} '_char']) = uicontrol('Style','edit',...
									'Parent',eval(idx{i}),...
									'Tag',['panel' pr{cur}],...
									'Callback',@me.readPanel,...
									'String',val,...
									'BackgroundColor',bgcoloredit);
							end
						elseif isnumeric(val)
							val = num2str(val);
							val = regexprep(val,'\s+',' ');
							handles.([pr{cur} '_num']) = uicontrol('Style','edit',...
								'Parent',eval(idx{i}),...
								'Tag',['panel' pr{cur}],...
								'String',val,...
								'Callback',@me.readPanel,...
								'FontName',MonoFont,...
								'BackgroundColor',bgcoloredit);
						else
							uiextras.Empty('Parent',eval(idx{i}),'BackgroundColor',bgcolor);
						end
					else
						uiextras.Empty('Parent',eval(idx{i}),'BackgroundColor',bgcolor);
					end
				end
				
				for j = 1:lp
					cur = lp*(i-1)+j;
					if cur <= length(pr)
						if isprop(me,[pr{cur} 'List'])
							if strcmp(me.([pr{cur} 'List']),'filerequestor')
								uicontrol('Style','pushbutton',...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'String','Select file...',...
								'FontName',SansFont,...
								'Tag',[pr{cur} '_button'],...
								'Callback',@me.selectFilePanel,...
								'FontSize', fsmall);
							else
								uicontrol('Style','text',...
								'Parent',eval(idx{i}),...
								'HorizontalAlignment','left',...
								'String',pr{cur},...
								'FontName',SansFont,...
								'FontSize', fsmall,...
								'BackgroundColor',bgcolor);
							end
						else
							uicontrol('Style','text',...
							'Parent',eval(idx{i}),...
							'HorizontalAlignment','left',...
							'String',pr{cur},...
							'FontName',SansFont,...
							'FontSize', fsmall,...
							'BackgroundColor',bgcolor);
						end
					else
						uiextras.Empty('Parent',eval(idx{i}),...
							'BackgroundColor',bgcolor);
					end
				end
				set(eval(idx{i}),'ColumnSizes',[-2 -1]);
			end
			for j = 1:lp2
				val = me.(pr2{j});
				if j <= length(pr2)
					handles.([pr2{j} '_bool']) = uicontrol('Style','checkbox',...
						'Parent',eval(idx{end}),...
						'Tag',['panel' pr2{j}],...
						'String',pr2{j},...
						'FontName',SansFont,...
						'FontSize', fsmall,...
						'Value',val,...
						'BackgroundColor',bgcolor);
				end
			end
			handles.readButton = uicontrol('Style','pushbutton',...
				'Parent',eval(idx{end}),...
				'Tag','readButton',...
				'Callback',@me.readPanel,...
				'String','Update');
			me.handles = handles;
			
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function selectFilePanel(me,varargin)
			if nargin > 0
				hin = varargin{1};
				if ishandle(hin)
					[f,p] = uigetfile('*.*','Select File:');
					re = regexp(get(hin,'Tag'),'(.+)_button','tokens','once');
					hout = me.handles.([re{1} '_char']);
					if ishandle(hout)
						set(hout,'String', [p f]);
					end
				end
			end
		end
		
		% ===================================================================
		%> @brief read values from a GUI properties panel for this object
		%>
		% ===================================================================
		function readPanel(me,varargin)
			if isempty(me.handles) || ~isa(me.handles.root,'uiextras.BoxPanel')
				return
			end
				
			pList = findAttributes(me,'SetAccess','public'); %our public properties
			dList = findAttributes(me,'Dependent', true); %find dependent properties
			pList = setdiff(pList,dList); %remove dependent properties as we don't want to set them!
			handleList = fieldnames(me.handles); %the handle name list
			handleListMod = regexprep(handleList,'_.+$',''); %we remove the suffix so names are equivalent
			outList = intersect(pList,handleListMod);
			
			for i=1:length(outList)
				hidx = strcmpi(handleListMod,outList{i});
				handleNameOut = handleListMod{hidx};
				handleName = handleList{hidx};
				handleType = regexprep(handleName,'^.+_','');
				while iscell(handleType);handleType=handleType{1};end
				switch handleType
					case 'list'
						str = get(me.handles.(handleName),'String');
						v = get(me.handles.(handleName),'Value');
						me.(handleNameOut) = str{v};
					case 'bool'
						me.(handleNameOut) = logical(get(me.handles.(handleName),'Value'));
						if isempty(me.(handleNameOut))
							me.(handleNameOut) = false;
						end
					case 'num'
						val = get(me.handles.(handleName),'String');
						if strcmpi(val,'true') %convert to logical
							me.(handleNameOut) = true;
						elseif strcmpi(val,'false') %convert to logical
							me.(handleNameOut) = true;
						else
							me.(handleNameOut) = str2num(val); %#ok<ST2NM>
						end
					case 'char'
						me.(handleNameOut) = get(me.handles.(handleName),'String');
				end
			end
			notify(me,'readPanelUpdate');
		end
			
		% ===================================================================
		%> @brief show GUI properties panel for this object
		%>
		% ===================================================================
		function showPanel(me)
			if isempty(me.handles)
				return
			end
			set(me.handles.root,'Enable','on');
			set(me.handles.root,'Visible','on');
		end
		
		% ===================================================================
		%> @brief hide GUI properties panel for this object
		%>
		% ===================================================================
		function hidePanel(me)
			if isempty(me.handles)
				return
			end
			set(me.handles.root,'Enable','off');
			set(me.handles.root,'Visible','off');
		end
		
		% ===================================================================
		%> @brief close GUI panel for this object
		%>
		% ===================================================================
		function closePanel(me,varargin)
			if isempty(me.handles)
				return
			end
			if isfield(me.handles,'root') && isgraphics(me.handles.root)
				readPanel(me);
				delete(me.handles.root);
			end
			if isfield(me.handles,'parent') && isgraphics(me.handles.parent,'figure')
				delete(me.handles.parent)
			end
			me.handles = [];
		end
		
		% ===================================================================
		%> @brief checkPaths
		%>
		%> @param
		%> @return
		% ===================================================================
		function varargout=cleanHandles(me,varargin)
			if isprop(me,'handles')
				me.handles = [];
			end
			if isprop(me,'h')
				me.handles = [];
			end
		end
		
	end %---END PUBLIC METHODS---%
	
	%=======================================================================
	methods (Abstract)%------------------ABSTRACT METHODS
	%=======================================================================
		%> initialise the stimulus
		out = setup(runObject)
		%> update the stimulus
		out = update(runObject)
		%>draw to the screen buffer
		out = draw(runObject)
		%> animate the settings
		out = animate(runObject)
		%> reset to default values
		out = reset(runObject)
	end %---END ABSTRACT METHODS---%
	
	%=======================================================================
	methods ( Static ) %----------STATIC METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief degrees2radians
		%>
		% ===================================================================
		function r = d2r(degrees)
		% d2r(degrees)
			r=degrees*(pi/180);
		end
		
		% ===================================================================
		%> @brief radians2degrees
		%>
		% ===================================================================
		function degrees = r2d(r)
		% r2d(radians)
			degrees=r*(180/pi);
		end
		
		% ===================================================================
		%> @brief findDistance in X and Y coordinates
		%>
		% ===================================================================
		function distance = findDistance(x1, y1, x2, y2)
		% findDistance(x1, y1, x2, y2)
			dx = x2 - x1;
			dy = y2 - y1;
			distance=sqrt(dx^2 + dy^2);
		end
		
		% ===================================================================
		%> @brief updatePosition returns dX and dY given an angle and delta
		%>
		% ===================================================================
		function [dX, dY] = updatePosition(delta,angle)
		% updatePosition(delta, angle)
			dX = delta .* cos(baseStimulus.d2r(angle));
			dY = delta .* sin(baseStimulus.d2r(angle));
		end
		
	end%---END STATIC METHODS---%
	
	%=======================================================================
	methods ( Access = protected ) %-------PRIVATE (protected) METHODS-----%
	%=======================================================================
		
		% ===================================================================
		%> @brief setRect
		%> setRect makes the PsychRect based on the texture and screen
		%> values, you should call computePosition() first to get xOut and
		%> yOut
		% ===================================================================
		function setRect(me)
			if ~isempty(me.texture)
				me.dstRect=Screen('Rect',me.texture);
				if me.mouseOverride && me.mouseValid
					me.dstRect = CenterRectOnPointd(me.dstRect, me.mouseX, me.mouseY);
				else
					me.dstRect=CenterRectOnPointd(me.dstRect, me.xOut, me.yOut);
				end
				me.mvRect=me.dstRect;
			end
		end
		
		% ===================================================================
		%> @brief setAnimationDelta
		%> setAnimationDelta for performance better not to use get methods for dX dY and
		%> delta during animation, so we have to cache these properties to private copies so that
		%> when we call the animate method, it uses the cached versions not the
		%> public versions. This method simply copies the properties to their cached
		%> equivalents.
		% ===================================================================
		function setAnimationDelta(me)
			me.delta_ = me.delta;
			me.dX_ = me.dX;
			me.dY_ = me.dY;
		end
		
		% ===================================================================
		%> @brief compute xOut and yOut
		%>
		% ===================================================================
		function computePosition(me)
			if me.mouseOverride && me.mouseValid
				me.xOut = me.mouseX; me.yOut = me.mouseY;
			else
				if isempty(me.findprop('angleOut'))
					[dx, dy]=pol2cart(me.d2r(me.angle),me.startPosition);
				else
					[dx, dy]=pol2cart(me.d2r(me.angleOut),me.startPositionOut);
				end
				me.xOut = me.xPositionOut + (dx * me.ppd) + me.sM.xCenter;
				me.yOut = me.yPositionOut + (dy * me.ppd) + me.sM.yCenter;
				if me.verbose; fprintf('---> computePosition: %s X = %gpx / %gpx / %gdeg | Y = %gpx / %gpx / %gdeg\n',me.fullName, me.xOut, me.xPositionOut, dx, me.yOut, me.yPositionOut, dy); end
			end
			setAnimationDelta(me);
		end
		
		% ===================================================================
		%> @brief xPositionOut Set method
		%>
		% ===================================================================
		function set_xPositionOut(me,value)
			me.xPositionOut = value*me.ppd;
			if ~me.inSetup; me.setRect; end
		end
		
		% ===================================================================
		%> @brief yPositionOut Set method
		%>
		% ===================================================================
		function set_yPositionOut(me,value)
			me.yPositionOut = value*me.ppd;
			if ~me.inSetup; me.setRect; end
		end
		
		% ===================================================================
		%> @brief Converts properties to a structure
		%>
		%>
		%> @param me this instance object
		%> @param tmp is whether to use the temporary or permanent properties
		%> @return out the structure
		% ===================================================================
		function out=toStructure(me,tmp)
			if ~exist('tmp','var')
				tmp = 0; %copy real properties, not temporary ones
			end
			fn = fieldnames(me);
			for j=1:length(fn)
				if tmp == 0
					out.(fn{j}) = me.(fn{j});
				else
					out.(fn{j}) = me.([fn{j} 'Out']);
				end
			end
		end
		
		% ===================================================================
		%> @brief Finds and removes transient properties
		%>
		%> @param me
		%> @return
		% ===================================================================
		function removeTmpProperties(me)
			fn=fieldnames(me);
			for i=1:length(fn)
				if isempty(regexp(fn{i},'^xOut$|^yOut$','once')) && ~isempty(regexp(fn{i},'Out$','once'))
					delete(me.findprop(fn{i}));
				end
			end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		%> @param me
		%> @return
		% ===================================================================
		function delete(me)
			me.handles = [];
			me.sM = [];
			if ~isempty(me.texture)
				try
					for i = 1:length(me.texture)
						Screen('Close',me.texture)
					end
				end
			end
			fprintf('--->>> Delete method called on stimulus: %s\n',me.fullName);
		end
		
	end%---END PRIVATE METHODS---%
end
