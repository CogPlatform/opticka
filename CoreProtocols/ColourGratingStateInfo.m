%> COLOUR GRATING state configuration file (also used by other protocols that use a 
%> fixation initiation then stimulus presentation with some variables changing 
%> on each trial, this gets loaded by opticka via runExperiment class.
%>
%> The following class objects (easily named handle copies) are already 
%> loaded and available to use. Each class has methods useful for running the task: 
%>
%> me		= runExperiment object ('self' in OOP terminology) 
%> s		= screenManager object
%> aM		= audioManager object
%> stims	= our list of stimuli (metaStimulus class)
%> sM		= State Machine (stateMachine class)
%> task		= task sequence (taskSequence class)
%> eT		= eyetracker manager
%> io		= digital I/O to recording system
%> rM		= Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
%> bR		= behavioural record plot (on-screen GUI during a task run)
%> uF       = user functions - add your own functions to this class
%> tS		= structure to hold general variables, will be saved as part of the data

%==================================================================
%------------------------General Settings--------------------------
% These settings are make changing the behaviour of the protocol easier. tS
% is just a struct(), so you can add your own switches or values here and
% use them lower down. Some basic switches like saveData, useTask,
% checkKeysDuringstimulus will influence the runeExperiment.runTask()
% functionality, not just the state machine. Other switches like
% includeErrors are referenced in this state machine file to change with
% functions are added to the state machine states…
tS.useTask					= true;		%==use taskSequence (randomised variable task object)
tS.rewardTime				= 150;		%==TTL time in milliseconds
tS.rewardPin				= 2;		%==Output pin, 2 by default with Arduino.
tS.keyExclusionPattern		= ["fixate","stimulus"]; %==which states to skip keyboard checking
tS.recordEyePosition		= false;	%==record local copy of eye position, **in addition** to the eyetracker?
tS.askForComments			= false;	%==little UI requestor asks for comments before/after run
tS.saveData					= true;		%==save behavioural and eye movement data?
tS.showBehaviourPlot		= true;		%==open the behaviourPlot figure? Can cause more memory use
tS.name						= 'Colour Grating'; %==name of this protocol
tS.nStims					= stims.n;	%==number of stimuli, taken from metaStimulus object
tS.tOut						= 0.5;		%==if wrong response, how long to time out before next trial
tS.CORRECT					= 1;		%==the code to send eyetracker for correct trials
tS.BREAKFIX					= -1;		%==the code to send eyetracker for break fix trials
tS.INCORRECT				= -5;		%==the code to send eyetracker for incorrect trials

%=================================================================
%----------------Debug logging to command window------------------
% uncomment each line to get specific verbose logging from each of these
% components; you can also set verbose in the opticka GUI to enable all of
% these…
%sM.verbose					= true;		%==print out stateMachine info for debugging
%stims.verbose				= true;		%==print out metaStimulus info for debugging
%io.verbose					= true;		%==print out io commands for debugging
%eT.verbose					= true;		%==print out eyelink commands for debugging
%rM.verbose					= true;		%==print out reward commands for debugging
%task.verbose				= true;		%==print out task info for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
% These settings define the initial fixation window and set up for the
% eyetracker. They may be modified during the task (i.e. moving the
% fixation window towards a target, enabling an exclusion window to stop
% the subject entering a specific set of display areas etc.)
%
% IMPORTANT: you need to make sure that the global state time is larger
% than the fixation timers specified here. Each state has a global timer,
% so if the state timer is 5 seconds but your fixation timer is 6 seconds,
% then the state will finish before the fixation time was completed!
tS.fixX						= 0;		% X position in degrees
tS.fixY						= 0;		% X position in degrees
tS.firstFixInit				= 1;		% time to search and enter fixation window
tS.firstFixTime				= 0.25;		% time to maintain fixation within windo
tS.firstFixRadius			= 2;		% radius in degrees
tS.strict					= true;		% do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionZone			= [];		% do we add an exclusion zone where subject cannot saccade to...
tS.stimulusFixTime			= 2;		% time to fix on the stimulus
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;

%==================================================================
%---------------------------Eyetracker setup-----------------------
% NOTE: the opticka GUI can set eyetracker options too, if you set options
% here they will OVERRIDE the GUI ones; if they are commented then the GUI
% options are used. me.elsettings and me.tobiisettings contain the GUI
% settings you can test if they are empty or not and set them based on
% that:
eT.name				= tS.name;
if me.dummyMode;	eT.isDummy = true; end %===use dummy or real eyetracker? 
if tS.saveData;		eT.recordData = true; end %===save ET data?					
if me.useEyeLink
	if isempty(me.elsettings)		%==check if GUI settings are empty
		eT.sampleRate				= 250;		%==sampling rate
		eT.calibrationStyle			= 'HV5';	%==calibration style
		eT.calibrationProportion	= [0.4 0.4]; %==the proportion of the screen occupied by the calibration stimuli
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation use 1-9 to show each dot, space to select fix as valid,
		% INS key ON EYELINK KEYBOARD to accept calibration!
		eT.remoteCalibration				= false; 
		%-----------------------
		eT.modify.calibrationtargetcolour	= [1 1 1]; %==calibration target colour
		eT.modify.calibrationtargetsize		= 2;		%==size of calibration target as percentage of screen
		eT.modify.calibrationtargetwidth	= 0.15;	%==width of calibration target's border as percentage of screen
		eT.modify.waitformodereadytime		= 500;
		eT.modify.devicenumber				= -1;		%==-1 = use any attachedkeyboard
		eT.modify.targetbeep				= 1;		%==beep during calibration
	end
elseif me.useTobii
	if isempty(me.tobiisettings)	%==check if GUI settings are empty
		eT.model					= 'Tobii Pro Spectrum';
		eT.sampleRate				= 300;
		eT.trackingMode				= 'human';
		eT.calibrationStimulus		= 'animated';
		eT.autoPace					= true;
		%-----------------------
		% remote calibration enables manual control and selection of each
		% fixation this is useful for a baby or monkey who has not been trained
		% for fixation
		eT.manualCalibration		= false;
		%-----------------------
		eT.calPositions				= [ .2 .5; .5 .5; .8 .5];
		eT.valPositions				= [ .5 .5 ];
	end
end

%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%Ensure we don't start with any exclusion zones set up
eT.resetExclusionZones();

%==================================================================
%----which states assigned as correct or break for online plot?----
bR.correctStateName				= "correct"; %use regex for better matching
bR.breakStateName				= ["breakfix","incorrect"];

%==================================================================
%--------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using taskSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use taskSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
% stims.choice				= [];
% n							= 1;
% in(n).name				= 'xyPosition';
% in(n).values				= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli				= 1;
% in(n).offset				= [];
% stims.stimulusTable		= in;
stims.choice 				= [];
stims.stimulusTable 		= [];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
stims.controlTable			= [];
stims.tableChoice			= 1;

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets			= {[2],[1,2]};
stims.setChoice				= 1;
hide(stims);

%==================================================================
% N x 2 cell array of regexpi strings, list to skip the current -> next state's exit functions; for example
% skipExitStates = {'fixate','incorrect|breakfix'}; means that if the currentstate is
% 'fixate' and the next state is either incorrect OR breakfix, then skip the FIXATE exit
% state. Add multiple rows for skipping multiple state's exit states.
sM.skipExitStates			= {'fixate','incorrect|breakfix'};

%===================================================================
%-----------------State Machine State Functions---------------------
% each cell {array} holds a set of anonymous function handles which are executed by the
% state machine to control the experiment. The state machine can run sets
% at entry, during, to trigger a transition, and at exit. Remember these
% {sets} need to access the objects that are available within the
% runExperiment context (see top of file). You can also add global
% variables/objects then use these. The values entered here are set on
% load, if you want up-to-date values then you need to use methods/function
% wrappers to retrieve/set them.

%--------------------pause entry
pauseEntryFcn = {
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawPhotoDiode(s,[0 0 0]);
	@()drawTextNow(s,'PAUSED, press [p] to resume...');
	@()disp('PAUSED, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()stopRecording(eT, true); %stop recording eye position data
	@()needFlip(me, false); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%--------------------pause exit
pauseExitFcn = {
	@()startRecording(eT, true); %start recording eye position data again
}; 

%====================================================
%====================================================PREFIXATE
%====================================================
%--------------------prefixation entry
prefixEntryFcn = { 
	@()needFlip(me, true); 
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()getStimulusPositions(stims,true); %make a struct the eT can use for drawing stim positions
	@()hide(stims);
};

prefixFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
};

prefixExitFcn = {
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()trackerMessage(eT,'V_RT MESSAGE END_FIX END_RT'); % Eyelink commands
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()startRecording(eT); %start recording eye position data again
	@()trackerDrawStatus(eT,'Start Fixation...',stims.stimulusPositions); %draw location of stimulus on eyelink
};

%====================================================
%====================================================FIXATE
%====================================================
%fixate entry
fixEntryFcn = {
	@()show(stims{tS.nStims});
	@()logRun(me,'INITFIX'); %fprintf current trial info to command window
};

%--------------------fix within
fixFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
	@()draw(stims); %draw stimulus
};

%--------------------test we are fixated for a certain length of time
inFixFcn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will jump to the correct state,
	% otherwise 'breakfix' is returned and the state machine will jump to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%--------------------exit fixation phase
fixExitFcn = { 
	@()updateFixationValues(eT,[],[],[],tS.stimulusFixTime); %reset fixation time for stimulus = tS.stimulusFixTime
	@()show(stims);
	@()trackerMessage(eT,'END_FIX');
};

%====================================================
%====================================================STIMULUS
%====================================================

%--------------------what to run when we enter the stim presentation state
stimEntryFcn = {
	% send an eyeTracker sync message (reset relative time to 0 after first flip of this state)
	@()doSyncTime(me);
	% send stimulus value strobe (value set by updateVariables(me) function of previous trial).
	% doStrobe(me) correctly times the strobe either before flip
	% (vpixx/display++) or after flip (LabJack etc.)
	@()doStrobe(me,true);
};

%--------------------what to run when we are showing stimuli
stimFcn =  {
	@()draw(stims);
	@()drawPhotoDiode(s,[1 1 1]);
	@()animate(stims); % animate stimuli for subsequent draw
};

%-----------------------test we are maintaining fixation
maintainFixFcn = {
	% this command performs the logic to search and then maintain fixation
	% inside the fixation window. The eyetracker parameters are defined above.
	% If the subject does initiate and then maintain fixation, then 'correct'
	% is returned and the state machine will jump to the correct state,
	% otherwise 'breakfix' is returned and the state machine will jump to the
	% breakfix state. If neither condition matches, then the state table below
	% defines that after 5 seconds we will switch to the incorrect state.
	@()testSearchHoldFixation(eT,'correct','breakfix'); 
};

%--------------------as we exit stim presentation state
stimExitFcn = {
	@()prepareStrobe(io, 255);
	@()doStrobe(me, true);
};

%====================================================
%====================================================DECISIONS:
%====================================================

%====================================================CORRECT
%--------------------if the subject is correct (small reward)
correctEntryFcn = {
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM, 2000, 0.1, 0.1); % correct beep
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.CORRECT));
	@()trackerDrawStatus(eT,'Correct! :-)',stims.stimulusPositions);
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%--------------------correct stimulus
correctFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
};

%--------------------when we exit the correct state
correctExitFcn = {
	@()sendStrobe(io,250);
	@()updatePlot(bR, me); %update our behavioural plot
	@()updateTask(me,tS.CORRECT); %make sure our taskSequence is moved to the next trial
	@()updateVariables(me); %randomise our stimuli, and set strobe value too for next trial
	@()update(stims); %update our stimuli ready for display on next trial
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions for next trial
	@()resetFixation(eT); %resets the fixation state timers	
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset the exclusion zones on eyetracker
	@()checkTaskEnded(me); %check if task is finished
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%====================================================INCORRECT/BREAKFIX
%--------------------incorrect entry
incEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.INCORRECT));
	@()trackerDrawStatus(eT,'Incorrect! :-(',stims.stimulusPositions);
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%--------------------break entry
breakEntryFcn = {
	@()beep(aM,400,0.5,1);
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,sprintf('TRIAL_RESULT %i',tS.BREAKFIX));
	@()trackerDrawStatus(eT,'Broke Fixation! :-(',stims.stimulusPositions);
	@()stopRecording(eT);
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()needEyeSample(me,false);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

%--------------------our incorrect stimulus
incFcn = {
	@()drawPhotoDiode(s,[0 0 0]);
};

%--------------------incorrect / break exit
incExitFcn = { 
	@()sendStrobe(io,251);
	@()updatePlot(bR, me); % update our behavioural plot;
	@()resetRun(task); % we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me, [], true); % randomise our stimuli, force override using true, set strobe value too
	@()update(stims); % update our stimuli ready for display
	@()resetFixation(eT); % resets the fixation state timers	
	@()resetFixationHistory(eT); % reset the recent eye position history
	@()resetExclusionZones(eT); % reset the exclusion zones on eyetracker
	@()getStimulusPositions(stims); % make a struct the eT can use for drawing stim positions
	@()checkTaskEnded(me); % check if task is finished
	@()needFlip(me, false);
	@()plot(bR, 1); % actually do our behaviour record drawing
};

%====================================================EYETRACKER
%--------------------calibration function
calibrateFcn = {
	@()drawBackground(s); % blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()rstop(io); 
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%--------------------drift correction function
driftFcn = {
	@()drawBackground(s); %blank the display
	@()stopRecording(eT); % stop recording in eyelink [tobii ignores this]
	@()setOffline(eT); % set eyelink offline [tobii ignores this]
	@()driftCorrection(eT) % enter drift correct
};

%====================================================GENERAL
%--------------------debug override
overrideFcn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%--------------------screenflash
flashFcn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%--------------------show 1deg size grid
gridFcn = {@()drawGrid(s)};

%==========================================================================
%==========================================================================
%==========================================================================
%--------------------------State Machine Table-----------------------------
% specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'		'next'		'time'	'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
%---------------------------------------------------------------------------------------------
'pause'		'prefix'	inf		pauseEntryFcn	[]				[]				pauseExitFcn;
'prefix'	'fixate'	1		prefixEntryFcn	prefixFcn		[]				prefixExitFcn;
'fixate'	'incorrect'	5		fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'	'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'timeout'	0.5		incEntryFcn		incFcn			[]				incExitFcn;
'breakfix'	'timeout'	0.5		breakEntryFcn	incFcn			[]				incExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn;
'timeout'	'prefix'	tS.tOut	[]				[]				[]				[];
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[];
'drift'		'pause'		0.5		driftFcn		[]				[]				[];
'override'	'pause'		0.5		overrideFcn		[]				[]				[];
'flash'		'pause'		0.5		flashFcn		[]				[]				[];
'showgrid'	'pause'		10		[]				gridFcn			[]				[];
};
%--------------------------State Machine Table-----------------------------
%==========================================================================

disp('=================>> Built state info file <<==================')
disp(stateInfoTmp)
disp('=================>> Built state info file <<=================')
clearvars -regexp '.+Fcn$' % clear the cell array Fns in the current workspace