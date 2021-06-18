%% DataProcessingEMAct.m
% Script to perform basic data processing on the measurements exported by
% Waveforms (as .csv files)
%
% Written by Bharat Dandu (bharatdandu@ucsb.edu)

fName = "Data/200Hz_2A_pp_3_4_2021.csv";

Data = readmatrix(fName);   % Per the formatting, the columns are time, LDV(V) and CoilCurrent(A)


%% Definitions

freqIntrst = 200;    % Frequency being measured

fs = 40000; % Read this directly off csv file, matlab discards this info during import
ldvScaling = 20;    % Read this off the LDV , units are mm/sec/V

timeVec = Data(:,1);

velData = Data(:,2)*ldvScaling/1000;    % velocities in m/s

accData = [diff(velData)*fs;0];     % accelerations in m/s^2, divide by 9.8 for units in g
accDataFilt = movmean(accData,10);
accDataFilt = medfilt1(accData,40); % some simple cleanup

posData = cumtrapz(velData)/fs;    % position in m

currData = Data(:,3);
currPP = max(currData)-min(currData);
%% Basic time domain plotting
figure(1)
hold on
plot(timeVec,accDataFilt/9.8,timeVec,currData);
legend('Measured Acc (g)','Current thru actuator (A)')
xlabel('Time (s)')
title("Acceleration of the actuator, "+num2str(freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p" )
hold off

figure(2)
plot(timeVec,detrend(posData)*1000,timeVec,currData);
legend('Measured Pos (mm)','Current thru actuator (A)')
xlabel('Time (s)')
title("Measured position of the actuator, "+num2str(freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p")

%%

%semilogx(20*log10(abs(fft(xcorr(accData)))))



