%% DataProcessingEMAct.m
% Script to perform basic data processing on the measurements taken with
% matlab - Slight variation on the prior script used for waveforms exports
%
% Written by Bharat Dandu (bharatdandu@ucsb.edu) - 4/17/21

%fName = "Data/200Hz_2A_pp_3_4_2021.csv";
%load(fName);   % Use for loading a .mat file. Loads
% measTimeVec,velData,currData,srcSig,fs,mode,freqIntrst variables

%% Definitions / manipulations

[b,a] = butter(8,1000/(fs/2));

if ndims(velData) == 2  % Lowpass and Collapse to a single channel by averaging across repetitions
    velData = filter(b,a,velData);
    currData = filter(b,a,currData);
    
    velData = mean(velData,2);
    currData = mean(currData,2);
end
accData = [diff(medfilt1(velData,10))*fs;0];     % accelerations in m/s^2, divide by 9.8 for units in g
accDataFilt = movmean(accData,10);
accDataFilt = medfilt1(accData,10); % some simple cleanup

posData = cumtrapz(velData)/fs;    % position in m

timeVec = measTimeVec;

%% Basic time domain plotting

figure(2)
plot(timeVec,accDataFilt/9.8,timeVec,currData);
legend('Measured Acc (g)','Current thru actuator (A)')
xlabel('Time (s)')
title("Acceleration of the actuator, "+num2str(freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p" )

%% Mode specific stuff

switch mode
    case 'sine'
        figure(1)
        plot(timeVec,velData,timeVec,currData);
        legend('Measured Velocity (m/sec)','Current thru actuator (A)')
        xlabel('Time (s)')
        title("Velocity of the actuator, "+num2str(freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p" )
        
        figure(3)
        plot(timeVec,detrend(posData)*1000,timeVec,currData);
        legend('Measured Pos (mm)','Current thru actuator (A)')
        xlabel('Time (s)')
        title("Measured position of the actuator, "+num2str(freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p")
        
        figure(4)
        thd(velData,fs);    % add an output argument to supress the plot and save the info
        xlim([0 1]);    % Limit the plot to 1kHz
        %%
    case  'chirp'
        figure(1)
        plot(timeVec,velData);
        ylabel('Measured Velocity (m/sec)');
        xlabel('Time (s)')
        title("Velocity of the actuator, "+num2str(currPP,'%.2f')+" A p-p" )
        
        figure(3)
        [TFxy,Freq] = tfestimate(srcSig,accData,[],[],[],fs);
        plot(Freq,20*log10(abs(TFxy)))
        xlabel('Frequency')
        ylabel('Magnitude response (in db)')
        title("Transfer fn of the actuator, (acceleration) "+num2str(currPP,'%.2f')+" A p-p");
        xlim([0 1000])
        
    case 'square'
        figure(1)
        plot(timeVec,velData,timeVec,currData);
        legend('Measured Velocity (m/sec)','Current thru actuator (A)')
        xlabel('Time (s)')
        title("Velocity of the actuator, "+num2str(freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p" )
        
        figure(3)
        plot(timeVec,detrend(cumtrapz((velData-mean(velData))/fs),1)*1000,timeVec,currData);
        legend('Measured Pos (mm)','Current thru actuator (A)')
        xlabel('Time (s)')
        title("Measured position of the actuator, "+num2str(freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p")
end



