%% DataAcqEMAct.m
% Script to perform data acquisition during characterization of EM actuator
%
% Written by Bharat Dandu (bharatdandu@ucsb.edu) - 4/17/21
% Expanded 6/17/21

clearvars -except forceBias;

%% Setup

% Setup up the measurement channels
measSet.ldv = true;
measSet.curr = true;
measSet.force = false;
measSet.therm = false;

measSet.ldvCh = "1";    % Set up channels. NOTE that if you modify this, modify forceBiasMeas and parseData accordingly
measSet.currCh = "2";
measSet.forceCh = string(5:10);
measSet.thermCh = "11";


% Modes and measurement lengths
measSet.mode = 'chirp';  % Choose 'sine', 'chirp', 'square', 'dc_steps' stimuli types

swGain = .2;     % Gain factor set in software. If we stick to the marked spot on the amp, 1 roughly corresponds to 1A p-p.
% CAUTION - Do not exceed gain of 3 beyond a couple of seconds, and NEVER
% exceed 4, at risk of burning out the coil or causing excessive wear
if swGain > 4
    error("Reduce sw gain");
end

switch measSet.mode
    case 'sine'
        measSet.freqIntrst = 4;   % frequency of interest. Set start and end freqs in an array if mode is 'chirp'
    case 'chirp'
        measSet.freqIntrst = [.5 1000];
    case 'square'
        measSet.freqIntrst = 2;
    case 'dc_steps'
        nSteps = 11;  % Number of frequency levels b/w -ve amp and + amp. Make sure this is odd to include 0
        warning('Please ensure that measTime*fs is cleanly divided by nSteps, else this gets messy')
end

measSet.zPadLen = .1;  % zero pad time in secs
measSet.measTime = 4+2*measSet.zPadLen;  % Measurement is x second long. Note that this is inclusive of the set zero padding

measSet.nReps = 3;   % Repetitions to clean up the data

% Define Daq, input & output channels
dq = daq("digilent");

if measSet.ldv
    ch_in1 = addinput(dq, "AD1", measSet.ldvCh, "Voltage");   % Ch 1 used for LDV measurement
    measSet.ldvScaling = 500;    % CAUTION!!! - Make sure LDV range is set appropriately.
    % 500 for 100Hz and up if you have 1A pp. 20 is best for <20 Hz. Note that
    % this is fullscale value, actual scaling factor is divided by 4.
end
if measSet.curr
    ch_in2 = addinput(dq, "AD1", measSet.currCh, "Voltage");   % Ch 2 used for current measurement
end
if measSet.force
    for i = 1:length(measSet.forceCh)   % Ch 5-10 used for force sensor measurements
        addinput(dq, "AD1", measSet.forceCh(i), "Voltage");
    end
end
if measSet.therm
    ch_in11 = addinput(dq, "AD1", measSet.thermCh, "Voltage");   % Ch 11 used for current measurement
end

ch_out = addoutput(dq, "AD1", "1", "Voltage");

dq.Rate = 40000;    % Doesn't always work. Do some testing to ensure that this fs is supported
measSet.fs = dq.Rate;

% If force sensor bias measurements aren't preesent in workspace, retake
if measSet.force && ~exist('forceBias','var')
    forceBiasMeas(dq,MeasSet);
end

%% Signal Definitions

timeVec = 0:1/measSet.fs:(measSet.measTime-2*measSet.zPadLen-1/measSet.fs);
zPad = zeros(1,round(measSet.zPadLen*measSet.fs));

switch measSet.mode
    case 'sine'
        srcSig = swGain*sin(2*pi*timeVec*measSet.freqIntrst);
        srcSig = [zPad srcSig zPad];    % manually handling zero padding. Not windowing for simplicity
        
        % add a pulse in the beginning for synchronizing repetitions if reqd
    case 'chirp'
        srcSig = swGain*chirp(timeVec,measSet.freqIntrst(1),timeVec(end),measSet.freqIntrst(2),'linear');  % Decide on linear vs logarithmic
        srcSig = [zPad srcSig zPad];    % manually handling zero padding. Not windowing for simplicity
        
    case 'square'
        srcSig = swGain*square(2*pi*timeVec*measSet.freqIntrst);  % square fn included inSignal processing toolbox
        srcSig = [zPad srcSig zPad];    % manually handling zero padding. Not windowing for simplicity
        
    case 'dc_steps'
        amp = linspace(-swGain, swGain, n+Steps);
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
measmnts.currData = zeros(length(srcSig),measSet.nReps);
measmnts.forceData.Fx = zeros(length(srcSig),measSet.nReps);
measmnts.forceData.Fy = zeros(length(srcSig),measSet.nReps);
measmnts.forceData.Fz = zeros(length(srcSig),measSet.nReps);
measmnts.thermData = zeros(length(srcSig),measSet.nReps);

% If force sensor bias measurements aren't preesent in workspace, retake
if measSet.force
    if ~exist('forceBias','var')
        input('Re-taking force bias measurements. Please acknowledge that there is nothing contacting the force sensor')
        forceBias = forceBiasMeas(dq,measSet);
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

for i = 1:measSet.nReps
    [inputDat,triggerTime] = readwrite(dq,outScanData); % Do simultaneous playback and record. Handy fn introduced in 2020a. Output is a timetable
    procData = parseData(inputDat, measSet);    % Process the read data
    
    if measSet.ldv
        measmnts.velData(:,i) = procData.velData;
    end
    if measSet.curr
        measmnts.currData(:,i) = procData.currData;
    end
    if measSet.force
        measmnts.forceData.Fx(:,i) = procData.forceData.Fx;
        measmnts.forceData.Fy(:,i) = procData.forceData.Fy;
        measmnts.forceData.Fz(:,i) = procData.forceData.Fz;
    end
    if measSet.therm
        measmnts.thermData(:,i) = procData.thermData;
    end
    
    measmnts.measTimeVec = inputDat.Time;
    
    pause(.5);  % Add a .5 sec delay between reps
end


%% Plors, derived values

% stackedplot(inputDat);    % if you want a quick way to visualize the recordings

if measSet.curr         % Current is pretty mandatory, but including it anyway
    currDataFilt = movmean(measmnts.currData,20);
    currPP = mean(max(currDataFilt)-min(currDataFilt));
end


%% Record to file

endTag = datetime('now','Format','M_d_yy__HH_mm_ss')   ;      % can make this just a regular measurement number (iterated for reps) or datetime
if strcmp(measSet.mode,'chirp')
    fName = "Data/" + string(measSet.mode) + "_" + num2str(currPP,'%.1f') + "_A_pp_"+string(endTag)+".mat";    % choose .mat or .csv
else
    fName = "Data/" + string(measSet.mode) + "_" + num2str(measSet.freqIntrst,'%.1f') + "_Hz_" + num2str(currPP,'%.1f') + "_A_pp_"+string(endTag)+".mat";    % choose .mat or .csv
end

save(fName,'measmnts','measSet','srcSig','currPP');     % Probably easier as all processing is in matlab
%writematrix(data,fName);


%% Function definitions

function forceBias = forceBiasMeas(dq,measSet)
% Function which identifies the bias currently experienced by the force
% sensor

zeroSig = zeros(12*measSet.fs,1);   % 12 second long zero signal
outScanData = zeroSig';
[inputDat,~] = readwrite(dq,outScanData);
fn = fieldnames(inputDat);
biasVec = zeros(length(zeroSig),length(measSet.forceCh));
for i = 1:length(measSet.forceCh)
    biasVec(:,i) = inputDat.(fn{i+5});  % There'll be an offset,
    % determine the exact value by looking at structure of inputDat.
    % For ex, Ch 5 will be inputDat.AD1_5, see if we're getting this
end
forceBias = mean(biasVec);
end


function procData = parseData(inputDat, measSet)
% Function which handles required data processing for data streams of each
% modality

fn = fieldnames(inputDat);
% Make sure you determine the exact channels to read in inputDat.
% For ex, Ch 5 will be inputDat.AD1_5, see if we're getting this

if measSet.ldv
    procData.velData = inputDat.(fn{1})*measSet.ldvScaling/(4*1000);    % velocities in m/s. Make sure names are accurate
    if max(inputDat.(fn{2})) > 3.9    % Throw a potential overrange warning (LDV voltage is supposed to be below 4V)
        warning('Overrange error for LDV')
    end
end

if measSet.curr
    procData.currData = inputDat.(fn{2})/.22;  % Current in amps. Measured Voltage across a .22ohm shunt resistor. Ensure correct channel is processed
end

if measSet.force
    rawMeas = zeros(length(inputDat.Time),measSet.forceCh);
    
    for i = 1:length(measSet.forceCh)
        rawMeas(:,i) = inputDat.(fn{i+4});  % Raw measurements from the daq
    end
    
    biasRemMeas = rawMeas - measSet.forceBias;  % Remove the bias measurements
    procData.forceData.Fx = biasRemMeas*measSet.MFx;    % Multiply with the scaling matrix
    procData.forceData.Fy = biasRemMeas*measSet.MFy;
    procData.forceData.Fz = biasRemMeas*measSet.MFz;
    
end

if measSet.therm
    ambientT = 20;  % Measure ambient temperature with a meter
    scaleFact = 1/.0041276;     % Scale factor based on k-type gradations and ampolification. Modify as reqd, will need a brief calibration
    procData.thermData = inputDat.(fn{11})*scaleFact + ambientT;  % Temperature in degrees celcius
end

end