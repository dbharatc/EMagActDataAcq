%% DataAcqEMAct.m
% Thermal measurements are different enough that it deserves it's own
% script
%
% Written by Bharat Dandu (bharatdandu@ucsb.edu) - 7/17/21

clearvars -except forceBias;

%% Setup

% Setup up the measurement channels
measSet.volt = true;
measSet.curr = true;
measSet.ldv = false;    % Pretty sure the ldv will not be used here
measSet.force = true;
measSet.therm = true;

% Modes and measurement lengths
measSet.measTime = 10;  % Each measurement is x second long. Note that zero padding is added in addition to this
measSet.zPadLen = 0;  % zero pad time in secs. Not used here
measSet.measTime = measSet.measTime + 2*measSet.zPadLen;
measSet.nReps = 1;   % Repetitions to clean up the data

measSet.roomTemp = 22;  % Specify room temperature in degrees celcius

measSet.mode = 'dc';  % Choose 'sine', 'chirp', 'square', 'dc_steps' stimuli types

switch measSet.mode
    case 'dc_steps'
        nSteps = 11;  % Number of frequency levels b/w -ve amp and + amp. Make sure this is odd to include 0
        warning('Please ensure that measTime*fs is cleanly divided by nSteps, else this gets messy')
end

if ~exist('run','var')
    run = 1;
end

currTargetSet = false;   % Decide if we want to specify a current target so that the swGain is set following a brief calibration phase (This same script run for a shorter time)
% For thermal measurements, might be best to test w/o this
currTarget = 1;     % Current target, in Amps p-p (AC) or Amps (DC).
% This assumes linearity of the current measurement with the scaling of
% voltage. NOTE - Verify how well this is working, and try and ensure that
% there is no clipping.

if run == 1
    if currTargetSet
        % Overwrite settings
        measSet.measTime = 1;  % Measurement is x second long. Note that zero padding is added in addition to this
        measSet.zPadLen = .05;  % zero pad time in secs
        measSet.measTime = measSet.measTime + 2*measSet.zPadLen;
        measSet.nReps = 3;   % Repetitions to clean up the data
        
        swGain = .5;    % Start with a low value for scalability
        recordFlag = false;
    else
        swGain = 1;     % Gain factor set in software. If we stick to the marked spot on the amp, 1 roughly corresponds to 1A p-p.
        % CAUTION - Do not exceed gain of 3 beyond a couple of seconds, and NEVER
        % exceed 4, at risk of burning out the coil or causing excessive wear
        recordFlag = true;
    end
end
if swGain > 4
    error("Reduce sw gain");
end


% Define Daq, input & output channels
dq = daq("ni");

% DAQ Specific
daqTag = "Dev4";
measSet.voltCh = "ai"+"0";    % Set up channels. NOTE that if you modify this, modify forceBiasMeas and parseData accordingly
measSet.currCh = "ai"+"1";
measSet.ldvCh = "ai"+"2";
measSet.forceCh = "ai"+["3" "4" "5" "6" "7" "13"];
measSet.thermCh = "ai"+"10";

dq.Rate = 100;    % Doesn't always work. Do some testing to ensure that this fs is supported
measSet.fs = dq.Rate;

% Output channels
ch_out = addoutput(dq, daqTag, "ao0", "Voltage");

% Define inputs
if measSet.volt
    ch_in1 = addinput(dq,daqTag, measSet.voltCh, "Voltage");   % Ch 1 used for current measurement
end
if measSet.curr
    ch_in2 = addinput(dq, daqTag, measSet.currCh, "Voltage");   % Ch 2 used for current measurement
end
if measSet.force
    for i = 1:length(measSet.forceCh)   % Ch x-x2 used for force sensor measurements
        ch_inF{i} = addinput(dq, daqTag, measSet.forceCh(i), "Voltage");
        ch_inF{i}.TerminalConfig = 'SingleEnded';
    end
    
    % If force sensor bias measurements aren't preesent in workspace, retake
    if ~exist('forceBias','var')
        input('Re-taking force bias measurements. Please acknowledge that there is nothing contacting the force sensor')
        forceBias = forceBiasMeas(dq,measSet);
    end
end
if measSet.therm
    ch_in10 = addinput(dq, daqTag, measSet.thermCh, "Voltage");   % Ch 15 used for current measurement
    ch_in10.TerminalConfig = 'SingleEnded';
    %input('Confirm that battery is connected to the breadboard, and calibration was redone today');
end


%% Signal Definitions

timeVec = 0:1/measSet.fs:(measSet.measTime-2*measSet.zPadLen-1/measSet.fs);
zPad = zeros(1,round(measSet.zPadLen*measSet.fs));

switch measSet.mode
    case 'dc'
        srcSig = swGain*ones(1,length(timeVec));
        
    case 'dc_steps'
        amp = linspace(-swGain, swGain, nSteps);
        for i = 1:nSteps
            indPerStep = round(measSet.measTime*measSet.fs/nSteps);     % indices per step
            srcSig(((i-1)*indPerStep +1): i*indPerStep) = amp(i)*ones(1,indPerStep);
        end
        srcSig = [zPad srcSig zPad];
        
        
    case 'others'   % other experimental stimuli
        srcSig = swGain*sin(2*pi*175*(0:1/measSet.fs:.04)).*hann((fs/25+1))';
        srcSig = swGain*sin(2*pi*175*(0:1/measSet.fs:.04)).*exp(-120*(0:1/measSet.fs:.04));
        %srcSig = [repmat(zPad,1,3) srcSig repmat(zPad,1,2)];
        
end

% Define all measurement signals anyway
measmnts.velData = zeros(length(srcSig),measSet.nReps);
measmnts.voltData = zeros(length(srcSig),measSet.nReps);
measmnts.currData = zeros(length(srcSig),measSet.nReps);
measmnts.forceData.Fx = zeros(length(srcSig),measSet.nReps);
measmnts.forceData.Fy = zeros(length(srcSig),measSet.nReps);
measmnts.forceData.Fz = zeros(length(srcSig),measSet.nReps);
measmnts.thermData = zeros(length(srcSig),measSet.nReps);
measmnts.measTimesStarts = [];

% If force sensor bias measurements aren't preesent in workspace, retake
if measSet.force
    if ~exist('forceBias','var')
        error('Force bias measmnts missing. Please run script from the beginning')
    end
    measSet.forceBias = forceBias;
    measSet.MFx=[0.00364 -0.04142 -0.16003 -1.67055 0.09189 1.63189];   % scaling matrix from Mengjia's models. I assume these values are directly from the ATI weebsite
    measSet.MFy=[0.05623 2.02388 -0.09620 -1.00659 -0.04977 -0.91361];
    measSet.MFz=[1.57108 -0.04694 1.92652 -0.04539 1.88337 -0.07715];
    measSet.MTx=[0.59557 12.2419 10.2107 -6.39444 -10.74076 -5.12130];
    measSet.MTy=[-9.94484 0.64581 7.72366 9.94193 5.20606 -10.13430];
    measSet.MTz=[0.19084 7.21740 0.69153 7.37822 0.45365 6.91279];
end

%% Play stimuli and record, define the channels appropriately

outScanData = srcSig';

heatingUpFlag = true;

prevTemp = roomTemp;

tBeg = datetime('now','Format','HH:mm:ss.SSS');     % The time at the very beginning - wave hands emoji

% Measurement loop
while heatingUpFlag
    tStart = datetime('now','Format','HH:mm:ss.SSS');   % Current time during the start of this run
    [inputDat,triggerTime] = readwrite(dq,outScanData); % Do simultaneous playback and record. Handy fn introduced in 2020a. Output is a timetable
    
    procData = parseData(inputDat, measSet);    % Process the read data
    
    if measSet.ldv
        measmnts.velData = procData.velData;
    end
    if measSet.volt
        measmnts.voltData = [measmnts.voltData ; procData.voltData];
    end
    if measSet.curr
        measmnts.currData = [measmnts.currData ; procData.currData];
    end
    if measSet.force
        measmnts.forceData.Fx = [measmnts.forceData.Fx ; procData.forceData.Fx];
        measmnts.forceData.Fy = [measmnts.forceData.Fy ; procData.forceData.Fy];
        measmnts.forceData.Fz = [measmnts.forceData.Fz ; procData.forceData.Fz];
    end
    if measSet.therm
        measmnts.thermData = [measmnts.thermData ; procData.thermData];
    end
    
    measmnts.measTimeVec = inputDat.Time;
    measmnts.measTimesStarts = [measmnts.measTimesStarts etime(datevec(tStart),datevec(tBeg))];   % Use this to reconstruct the final timetable and sample to a smaller grid
    
    currentTemp = mean(procData.thermData((measSet.measTime-1)*measSet.fs:measSet.measTime*measSet.fs));   % Measure the average temp in the last second of measurement
    
    if (currentTemp < 1.02 * prevTemp)
        heatingUpFlag = false;
    end
    
    prevTemp = currentTemp;
    
    %pause(.5);  % Add a .5 sec delay between reps
end

%% Cooldown phase
coolingDownFlag = true;

% Cooldown loop
while coolingDownFlag
    tStart = datetime('now','Format','HH:mm:ss.SSS');   % Current time during the start of this run
    [inputDat,triggerTime] = readwrite(dq,outScanData); % Do simultaneous playback and record. Handy fn introduced in 2020a. Output is a timetable
    
    procData = parseData(inputDat, measSet);    % Process the read data
    
    if measSet.ldv
        measmnts.velData = procData.velData;
    end
    if measSet.volt
        measmnts.voltData = [measmnts.voltData ; procData.voltData];
    end
    if measSet.curr
        measmnts.currData = [measmnts.currData ; procData.currData];
    end
    if measSet.force
        measmnts.forceData.Fx = [measmnts.forceData.Fx ; procData.forceData.Fx];
        measmnts.forceData.Fy = [measmnts.forceData.Fy ; procData.forceData.Fy];
        measmnts.forceData.Fz = [measmnts.forceData.Fz ; procData.forceData.Fz];
    end
    if measSet.therm
        measmnts.thermData = [measmnts.thermData ; procData.thermData];
    end
    
    measmnts.measTimeVec = inputDat.Time;
    measmnts.measTimesStarts = [measmnts.measTimesStarts etime(datevec(tStart),datevec(tBeg))];   % Use this to reconstruct the final timetable and sample to a smaller grid
    
    currentTemp = mean(procData.thermData((measSet.measTime-1)*measSet.fs:measSet.measTime*measSet.fs));   % Measure the average temp in the last second of measurement
    
    if currentTemp < 1.02 * roomTemp
        coolingDownFlag = false;    % i.e. it has done cooling down
    end
    
end

disp('Device is at room temperature!!');




%% Plors, derived values

% stackedplot(inputDat);    % if you want a quick way to visualize the recordings

if measSet.curr         % Current is pretty mandatory, but including it anyway
    currDataFilt = movmean(measmnts.currData,20);
    currPP = mean(max(currDataFilt)-min(currDataFilt));     % One disadvantage of this is that it measures current at low freqs. Will have to do something slightly more complicated if we want current at a spcific freq
end


%% Record to file
if recordFlag
    endTag = datetime('now','Format','M_d_yy__HH_mm_ss')   ;      % can make this just a regular measurement number (iterated for reps) or datetime
    if strcmp(measSet.mode,'chirp')
        fName = "Data/" + string(measSet.mode) + "_" + num2str(currPP,'%.1f') + "_A_pp_"+string(endTag)+".mat";    % choose .mat or .csv
    else
        fName = "Data/" + string(measSet.mode) + "_" + num2str(measSet.freqIntrst,'%.1f') + "_Hz_" + num2str(currPP,'%.1f') + "_A_pp_"+string(endTag)+".mat";    % choose .mat or .csv
    end
    
    save(fName,'measmnts','measSet','srcSig','currPP');     % Probably easier as all processing is in matlab
    %writematrix(data,fName);
end

%% Recompute swGain if specified, reset the run
if currTargetSet
    recordFlag = true;  % Set it up so data is recorded for the next trial
    
    if run == 1
        swGain = swGain * currTarget / currPP;    % Compute updated sw gain
        run = run + 1;
        DataAcqEMAct;   % Start the next run with the actual specified values
    else
        clearvars run;
    end
    
end

