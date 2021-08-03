%> SACCADE / ANTISACCADE state file, this gets loaded by opticka via 
%> runExperiment class. You can set up any state and define the logic of
%> which functions to run when you enter, are within, or exit a state.
%> Objects provide many methods you can run, like sending triggers, showing
%> stimuli, controlling the eyetracker etc.
%
%> The following class objects are already loaded and available to use: 
%
%> me = runExperiment object
%> io = digital I/O to recording system
%> s = screenManager
%> aM = audioManager
%> sM = State Machine
%> eT = eyetracker manager
%> task  = task sequence (taskSequence class)
%> rM = Reward Manager (LabJack or Arduino TTL trigger to reward system/Magstim)
%> bR = behavioural record plot (on screen GUI during task run)
%> stims = our list of stimuli
%> tS = general struct to hold variables for this run, will be saved as part of the data

%==================================================================
%---------------------------TASK SWITCH----------------------------
tS.type						= 'antisaccade'; %will be be saccade or antisaccade task run?
tS.includeErrors			= true; %do we update the trial number even for incorrect saccades, if true then we call updateTask for both correct and incorrect, otherwise we only call updateTask() for correct responses

%==================================================================
%----------------------General Settings----------------------------
tS.useTask					= true; %==use taskSequence (randomises stimulus variables)
tS.rewardTime				= 250; %==TTL time in milliseconds
tS.rewardPin				= 11; %==Output pin, 2 by default with Arduino.
tS.checkKeysDuringStimulus  = true; %==allow keyboard control? Slight drop in performance
tS.recordEyePosition		= true; %==record eye position within PTB, **in addition** to the EDF?
tS.askForComments			= false; %==little UI requestor asks for comments before/after run
tS.saveData					= true; %==save behavioural and eye movement data?
tS.name						= 'saccade-antisaccade'; %==name of this protocol
tS.tOut						= 5; %if wrong response, how long to time out before next trial
tS.CORRECT 					= 1; %==the code to send eyetracker for correct trials
tS.BREAKFIX 				= -1; %==the code to send eyetracker for break fix trials
tS.INCORRECT 				= -5; %==the code to send eyetracker for incorrect trials

%==================================================================
%---------------Debug logging to command window--------------------
io.verbose					= false; %print out io commands for debugging
eT.verbose					= true; %print out eyetracker commands for debugging
rM.verbose					= false; %print out reward commands for debugging

%==================================================================
%-----------------INITIAL Eyetracker Settings----------------------
tS.fixX						= 0; % X position in degrees (screen center)
tS.fixY						= 0; % X position in degrees (screen center)
tS.firstFixInit				= 3; % time to search and enter fixation window
tS.firstFixTime				= [0.5 1.25]; % time to maintain fixation within window
tS.firstFixRadius			= 3; % radius in degrees
tS.strict					= true; % do we forbid eye to enter-exit-reenter fixation window?
tS.exclusionRadius			= 5; % radius of the exclusion zone...
me.lastXPosition			= tS.fixX;
me.lastYPosition			= tS.fixY;
me.lastXExclusion			= [];
me.lastYExclusion			= [];
tS.targetFixInit			= 1; % time to find the target
tS.targetFixTime			= 0.3; % to to maintain fixation on target 
tS.targetRadius				= 8; %radius to fix within.

%==================================================================
%---------------------------Eyetracker setup-----------------------
if me.useEyeLink
	warning('Note this protocol is optimised for the Tobii eyetracker, beware...')
	eT.name 					= tS.name;
	eT.sampleRate 				= 250; % sampling rate
	eT.calibrationStyle 		= 'HV3'; % calibration style
	eT.calibrationProportion	= [0.4 0.4]; %the proportion of the screen occupied by the calibration stimuli
	if tS.saveData == true;		eT.recordData = true; end %===save EDF file?
	if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
	%-----------------------
	% remote calibration enables manual control and selection of each fixation
	% this is useful for a baby or monkey who has not been trained for fixation
	% use 1-9 to show each dot, space to select fix as valid, INS key ON EYELINK KEYBOARD to
	% accept calibration!
	eT.remoteCalibration		= true; 
	%-----------------------
	eT.modify.calibrationtargetcolour = [1 1 1]; % calibration target colour
	eT.modify.calibrationtargetsize = 2; % size of calibration target as percentage of screen
	eT.modify.calibrationtargetwidth = 0.15; % width of calibration target's border as percentage of screen
	eT.modify.waitformodereadytime	= 500;
	eT.modify.devicenumber 			= -1; % -1 = use any attachedkeyboard
	eT.modify.targetbeep 			= 1; % beep during calibration
elseif me.useTobii
	eT.name 					= tS.name;
	eT.model					= 'Tobii Pro Spectrum';
	eT.trackingMode				= 'human';
	eT.calPositions				= [ .2 .5; .5 .5; .8 .5];
	eT.valPositions				= [ .5 .5 ];
	if me.dummyMode;			eT.isDummy = true; end %===use dummy or real eyetracker? 
end
%Initialise the eyeTracker object with X, Y, FixInitTime, FixTime, Radius, StrictFix
eT.updateFixationValues(tS.fixX, tS.fixY, tS.firstFixInit, tS.firstFixTime, tS.firstFixRadius, tS.strict);
%make sure we don't start with any exclusion zones set up
eT.resetExclusionZones();

%======================================================================
%---REGEX for which states assigned correct or break for online plot---
bR.correctStateName				= '^correct';
bR.breakStateName				= '^(breakfix|incorrect)';

%==================================================================
%-------------------randomise stimulus variables every trial?-----------
% if you want to have some randomisation of stimuls variables without
% using stimulusSequence task, you can uncomment this and runExperiment can
% use this structure to change e.g. X or Y position, size, angle
% see metaStimulus for more details. Remember this will not be "Saved" for
% later use, if you want to do controlled methods of constants experiments
% use stimulusSequence to define proper randomised and balanced variable
% sets and triggers to send to recording equipment etc...
%
% stims.choice				= [];
% n								= 1;
% in(n).name					= 'xyPosition';
% in(n).values					= [6 6; 6 -6; -6 6; -6 -6; -6 0; 6 0];
% in(n).stimuli					= 1;
% in(n).offset					= [];
% stims.stimulusTable		= in;
stims.choice 				= [];
stims.stimulusTable 		= [];

%==================================================================
%-------------allows using arrow keys to control variables?-------------
% another option is to enable manual control of a table of variables
% this is useful to probe RF properties or other features while still
% allowing for fixation or other behavioural control.
% Use arrow keys <- -> to control value and up/down to control variable
stims.controlTable = [];
stims.tableChoice = 1;

%==================================================================
%this allows us to enable subsets from our stimulus list
% 1 = grating | 2 = fixation cross
stims.stimulusSets = {[2],[1,2]};
stims.setChoice = 1;
hide(stims);

%==================================================================
%which stimulus in the list is used for a fixation target? For this protocol it means
%the subject must fixate this stimulus (the saccade target is #1 in the list) to get the
%reward. Also which stimulus to set an exclusion zone around (where a
%saccade into this area causes an immediate break fixation).
stims.fixationChoice = 1;
stims.exclusionChoice = 2;

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

%pause entry
pauseEntryFcn = { 
	@()hide(stims);
	@()drawBackground(s); %blank the subject display
	@()drawTextNow(s,'Paused, press [p] to resume...');
	@()disp('Paused, press [p] to resume...');
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawText(eT,'PAUSED, press [P] to resume...');
	@()trackerMessage(eT,'TRIAL_RESULT -100'); %store message in EDF
	@()disableFlip(me); % no need to flip the PTB screen
	@()needEyeSample(me,false); % no need to check eye position
};

%pause exit
pauseExitFcn = {
	
}; 

prefixEntryFcn = { 
	@()enableFlip(me); 
};

prefixFcn = {};

%fixate entry
fixEntryFcn = { 
	@()updateFixationValues(eT,tS.fixX,tS.fixY,[],tS.firstFixTime); %reset fixation window
	@()trackerMessage(eT,sprintf('TRIALID %i',getTaskIndex(me))); %Eyelink start trial marker
	@()trackerMessage(eT,['UUID ' UUID(sM)]); %add in the uuid of the current state for good measure
	@()trackerClearScreen(eT); % blank the eyelink screen
	@()trackerDrawFixation(eT); % draw fixation window on eyetracker display
	@()trackerDrawStimuli(eT,stims.stimulusPositions); %draw location of stimulus on eyetracker
	@()needEyeSample(me,true); % make sure we start measuring eye position
	@()edit(stims,3,'alphaOut',0.5); 
	@()edit(stims,3,'alpha2Out',1);
	@()show(stims{3});
	@()logRun(me,'INITFIX'); %fprintf current trial info to command window
};

%fix within
fixFcn = {
	@()draw(stims); %draw stimulus
};

%test we are fixated for a certain length of time
inFixFcn = { 
	@()testSearchHoldFixation(eT,'stimulus','incorrect')
};

%exit fixation phase
fixExitFcn = { 
	@()updateFixationTarget(me, tS.useTask, tS.targetFixInit, tS.targetFixTime, tS.targetRadius, tS.strict); ... %use our stimuli values for next fix X and Y
	@()updateExclusionZones(me, tS.useTask, tS.exclusionRadius);
	@()edit(stims,3,'alphaOut',0); %dim fix spot
	@()edit(stims,3,'alpha2Out',0.05); %dim fix spot
	@()trackerMessage(eT,'END_FIX');
}; 

if strcmpi(tS.type,'saccade')
	fixExitFcn = [ fixExitFcn; {@()show(stims{1}); @()hide(stims{2})} ];
else
	fixExitFcn = [ fixExitFcn; {@()hide(stims{1}); @()show(stims{2})} ];
end

%what to run when we enter the stim presentation state
stimEntryFcn = { 
	@()doStrobe(me,true)
};

%what to run when we are showing stimuli
stimFcn =  { 
	@()draw(stims);
	@()animate(stims); % animate stimuli for subsequent draw
};

%test we are maintaining fixation
maintainFixFcn = {
	@()testSearchHoldFixation(eT,'correct','breakfix'); % tests finding and maintaining fixation
};

%as we exit stim presentation state
stimExitFcn = { 
	@()setStrobeValue(me,255); 
	@()doStrobe(me,true);
};

%if the subject is correct (small reward)
correctEntryFcn = { 
	@()timedTTL(rM, tS.rewardPin, tS.rewardTime); % send a reward TTL
	@()beep(aM,2000); % correct beep
	@()trackerDrawText(eT,'Correct! :-)');
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.CORRECT)]);
	@()needEyeSample(me,false); % no need to collect eye data until we start the next trial
	@()hide(stims);
	@()sendTTL(io,4);
	@()logRun(me,'CORRECT'); %fprintf current trial info
};

%correct stimulus
correctFcn = { 
	@()drawBackground(s);
};

%when we exit the correct state
correctExitFcn = {
	@()updateVariables(me); %randomise our stimuli, and set strobe value too
	@()updateTask(me,CORRECT); %make sure our taskSequence is moved to the next trial
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()trackerClearScreen(eT); 
	@()updatePlot(bR, eT, sM); %update our behavioural plot
	@()checkTaskEnded(me); %check if task is finished
	@()drawnow;
};

%incorrect entry
incEntryFcn = { 
	@()beep(aM,400,0.5,1);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Incorrect! :-(');
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.INCORRECT)]);
	@()needEyeSample(me,false);
	@()sendTTL(io,6);
	@()hide(stims);
	@()logRun(me,'INCORRECT'); %fprintf current trial info
}; 

%our incorrect stimulus
incFcn = {
	@()drawBackground(s);
};

%incorrect / break exit
incExitFcn = {
	@()resetRun(task);... %we randomise the run within this block to make it harder to guess next trial
	@()updateVariables(me); %randomise our stimuli, don't run updateTask(task), and set strobe value too
	@()update(stims); %update our stimuli ready for display
	@()getStimulusPositions(stims); %make a struct the eT can use for drawing stim positions
	@()resetExclusionZones(eT); %reset the exclusion zones
	@()trackerClearScreen(eT); 
	@()checkTaskEnded(me); %check if task is finished
	@()updatePlot(bR, eT, sM); %update our behavioural plot;
	@()drawnow;
};

if tS.includeErrors
	incExitFcn = [ incExitFcn; {@()updateTask(me,tS.BREAKFIX)} ]; %make sure our taskSequence is moved to the next trial
end

%break entry
breakEntryFcn = {
	@()beep(aM,400,0.5,1);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Broke maintain fix! :-(');
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.BREAKFIX)]);
	@()needEyeSample(me,false);
	@()sendTTL(io,5);
	@()hide(stims);
	@()logRun(me,'BREAKFIX'); %fprintf current trial info
};

exclEntryFcn = {
	@()beep(aM,400,0.5,1);
	@()trackerClearScreen(eT);
	@()trackerDrawText(eT,'Exclusion Zone entered! :-(');
	@()trackerMessage(eT,'END_RT');
	@()trackerMessage(eT,['TRIAL_RESULT ' str2double(tS.BREAKFIX)]);
	@()needEyeSample(me,false);
	@()sendTTL(io,5);
	@()hide(stims);
	@()logRun(me,'EXCLUSION'); %fprintf current trial info
};

%calibration function
calibrateFcn = { 
	@()rstop(io); 
	@()trackerSetup(eT);  %enter tracker calibrate/validate setup mode
};

%debug override
overrideFcn = { @()keyOverride(me) }; %a special mode which enters a matlab debug state so we can manually edit object values

%screenflash
flashFcn = { @()flashScreen(s, 0.2) }; % fullscreen flash mode for visual background activity detection

%magstim
magstimFcn = { 
	@()drawBackground(s);
	@()stimulate(mS); % run the magstim
};

%show 1deg size grid
gridFcn = {@()drawGrid(s)};

%----------------------State Machine Table-------------------------
disp('================>> Building state info file <<================')
%specify our cell array that is read by the stateMachine
stateInfoTmp = {
'name'      'next'		'time'  'entryFcn'		'withinFcn'		'transitionFcn'	'exitFcn';
'pause'		'prefix'	inf		pauseEntryFcn	[]				[]				pauseExitFcn;
'prefix'	'fixate'	0.5		prefixEntryFcn	prefixFcn		[]				[];
'fixate'	'incorrect'	5	 	fixEntryFcn		fixFcn			inFixFcn		fixExitFcn;
'stimulus'  'incorrect'	5		stimEntryFcn	stimFcn			maintainFixFcn	stimExitFcn;
'incorrect'	'prefix'	3		incEntryFcn		incFcn			[]				incExitFcn;
'breakfix'	'prefix'	tS.tOut	breakEntryFcn	incFcn			[]				incExitFcn;
'exclusion'	'prefix'	tS.tOut	exclEntryFcn	incFcn			[]				incExitFcn;
'correct'	'prefix'	0.5		correctEntryFcn	correctFcn		[]				correctExitFcn;
'calibrate' 'pause'		0.5		calibrateFcn	[]				[]				[];
'override'	'pause'		0.5		overrideFcn		[]				[]				[];
'flash'		'pause'		0.5		flashFcn		[]				[]				[];
'magstim'	'prefix'	0.5		[]				magstimFcn		[]				[];
'showgrid'	'pause'		10		[]				gridFcn			[]				[];
};

disp(stateInfoTmp)
disp('================>> Loaded state info file  <<================')
clear pauseEntryFcn fixEntryFcn fixFcn inFixFcn fixExitFcn stimFcn maintainFixFcn incEntryFcn ...
	incFcn incExitFcn breakEntryFcn breakFcn correctEntryFcn correctFcn correctExitFcn ...
	calibrateFcn overrideFcn flashFcn gridFcn