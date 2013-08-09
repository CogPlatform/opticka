function dotstest()

runtime = 0.5;
n = dotsStimulus();
n.size = 10;
n.speed = 2;
n.colour = [1 1 1];
n.coherence = 1;

s = screenManager('verbose',false,'blend',true,'screen',0,...
	'bitDepth','8bit','debug',true,...
		'windowed',true,'backgroundColour',[0.2 0.2 0.2 0]); %use a temporary screenManager object
screenVals = open(s); %open PTB screen
setup(n,s); %setup our stimulus object
%drawGrid(s); %draw +-5 degree dot grid
%drawScreenCenter(s); %centre spot

%Set up up/down procedure:
up = 1;                     %increase after 1 wrong
down = 3;                   %decrease after 3 consecutive right
StepSizeDown = 0.05;        
StepSizeUp = 0.05;
stopcriterion = 'trials';   
stoprule = 25;
startvalue = 0.7;           %intensity on first trial

UDLEFT = PAL_AMUD_setupUD('up',up,'down',down);
UDLEFT = PAL_AMUD_setupUD(UDLEFT,'StepSizeDown',StepSizeDown,'StepSizeUp', ...
    StepSizeUp,'stopcriterion',stopcriterion,'stoprule',stoprule, ...
    'startvalue',startvalue,'xMin',0,'xMax',1);

UDRIGHT = UDLEFT;
WaitSecs(0.1)

try
	breakloop = false;

	vbl = Screen('Flip',s.win);
	Screen('DrawingFinished', s.win); %tell PTB/GPU to draw

	while ~breakloop

		%select new angle and coherence
		angleToggle = randi([0 1]) * 180;
		n.angleOut = angleToggle;
		if angleToggle == 180
			n.coherenceOut = UDRIGHT.xCurrent;
			x = UDRIGHT.stop;
			xx=length(UDRIGHT.x);
		else
			n.coherenceOut = UDLEFT.xCurrent;
			x = UDLEFT.stop;
			xx=length(UDLEFT.x);
		end
		update(n);
		fprintf('---> Angle: %i | Coh: %.2g  | stop: %i -- %i', angleToggle, n.coherenceOut,x,xx);

		drawSpot(s,0.2,[1 1 0]);
		Screen('Flip',s.win); %flip the buffer
		WaitSecs(0.5);

		vbls = Screen('Flip',s.win); %flip the buffer
		while GetSecs <= vbls+runtime
			draw(n); %draw stimulus
			drawSpot(s,0.2,[0.5 0.5 0]);
			Screen('DrawingFinished', s.win); %tell PTB/GPU to draw
			animate(n); %animate stimulus, will be seen on next draw
			vbl = Screen('Flip',s.win); %flip the buffer
		end	
		vbl = Screen('Flip',s.win);

		keyIsDown = false;
		response = [];
		while ~keyIsDown
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode);
				if iscell(rchar);rchar=rchar{1};end
				switch rchar
					case {'LeftArrow','left'} %previous variable 1 value
						if angleToggle == 180
							response = 1;
						else
							response = 0;
						end
					case {'RightArrow','right'} %next variable 1 value
						if angleToggle == 0
							response = 1;
						else
							response = 0;
						end
					case {'q'}
						breakloop = true;
				end
			end
		end
		if angleToggle == 180
			if ~UDRIGHT.stop && ~isempty(response)
				UDRIGHT = PAL_AMUD_updateUD(UDRIGHT, response); %update UD structure
			end
		else
			if ~UDLEFT.stop && ~isempty(response)
				UDLEFT = PAL_AMUD_updateUD(UDLEFT, response); %update UD structure
			end
		end

		Screen('Flip',s.win); %flip the buffer
		fprintf('RESPONSE = %i\n', response);
		
		if UDRIGHT.stop==1 && UDLEFT.stop==1
			breakloop = true;
		end
		WaitSecs(1);
	end
	
	Screen('Flip',s.win);
	WaitSecs(1);
	Priority(0); ListenChar(0); ShowCursor;
	close(s); %close screen
	reset(n); %reset our stimulus ready for use again

	%Threshold estimate as mean of all but the first three reversal points
	Mean = PAL_AMUD_analyzeUD(UDLEFT, 'reversals', max(UDLEFT.reversal)-3);
	message = sprintf('\rThreshold LEFT estimate as mean of all but last three');
	message = strcat(message,sprintf(' reversals: %6.4f', Mean));
	disp(message);
	%Threshold estimate as mean of all but the first three reversal points
	Mean = PAL_AMUD_analyzeUD(UDRIGHT, 'reversals', max(UDRIGHT.reversal)-3);
	message = sprintf('\rThreshold RIGHT estimate as mean of all but last three');
	message = strcat(message,sprintf(' reversals: %6.4f', Mean));
	disp(message);
	
	t = 1:length(UDLEFT.x);
	figure('name','Up/Down Adaptive Procedure');
	plot(t,UDLEFT.x,'k');
	hold on;
	plot(t(UDLEFT.response == 1),UDLEFT.x(UDLEFT.response == 1),'ko', 'MarkerFaceColor','k');
	plot(t(UDLEFT.response == 0),UDLEFT.x(UDLEFT.response == 0),'ko', 'MarkerFaceColor','w');
	set(gca,'FontSize',16);
	title('LEFT')
	axis([0 max(t)+1 min(UDLEFT.x)-(max(UDLEFT.x)-min(UDLEFT.x))/10 max(UDLEFT.x)+(max(UDLEFT.x)-min(UDLEFT.x))/10]);
	
	t = 1:length(UDRIGHT.x);
	figure('name','Up/Down Adaptive Procedure');
	plot(t,UDRIGHT.x,'k');
	hold on;
	plot(t(UDRIGHT.response == 1),UDRIGHT.x(UDRIGHT.response == 1),'ko', 'MarkerFaceColor','k');
	plot(t(UDRIGHT.response == 0),UDRIGHT.x(UDRIGHT.response == 0),'ko', 'MarkerFaceColor','w');
	set(gca,'FontSize',16);
	title('RIGHT')
	axis([0 max(t)+1 min(UDRIGHT.x)-(max(UDRIGHT.x)-min(UDRIGHT.x))/10 max(UDRIGHT.x)+(max(UDRIGHT.x)-min(UDRIGHT.x))/10]);

catch
	Priority(0); ListenChar(0); ShowCursor;
	reset(n);
	close(s); %close screen
end
end
