%% DataProcessingFolders.m
% Script to generate summary plots from sequentially captured data saved in
% specific folders
%
% Written by Bharat Dandu (bharatdandu@ucsb.edu) - 7/29/21

clearvars

%% Definitions

folderName = "Data/Ferrofluid 1/DSS";

fileInfo = dir(folderName+"/*.mat");
numFiles = length(fileInfo);

% Data to save from each file
currData = zeros(1,numFiles);

%% Run through files, collect data

load(fullfile(folderName, fileInfo(1).name));    % Load 1 file to check what type of data is being considered
if measSet.mode == 'sine'   
    freqsInterest = logspace(log10(5),log10(1000),20);  % Data is slightly more involved for discrete sine data, pre-define
    currTargets = [.1 .5 1 2];
    vel = cell(length(freqsInterest),length(currTargets));
    acc = cell(length(freqsInterest),length(currTargets));
    pos = cell(length(freqsInterest),length(currTargets));
    thdArr = zeros(length(freqsInterest),length(currTargets));
    currArr = zeros(length(freqsInterest),length(currTargets));
end


for fileInd = 1:numFiles
    fName = fullfile(folderName, fileInfo(fileInd).name);
    load(fName);
    
    DataProcessingEMAct;    % Run the dedicated processing script for each file
    currPPData(fileInd) = currPP;   % Current is constant
    
    switch measSet.mode
        case 'chirp'
            filtAccEnv{fileInd} = envelope(accDataFilt/9.8);
            velEnv{fileInd} = envelope(velData);
            TFxyDat{fileInd} = TFxy;
        case 'square'
            filtAcc{fileInd} = accDataFilt/9.8;
            vel{fileInd} = velData;
            pos{fileInd} = detrend(cumtrapz((velData-mean(velData))/measSet.fs),1)*1000;
        case 'sine'
            freqInd = find(freqsInterest == measSet.freqIntrst);
            currInd = find(currTargets > .7*currPP & currTargets < 1.5*currPP); % Current is calculated, so finding an approx match
            if currPP > 2.5
                currInd = 4;
            end
            
            vel{freqInd,currInd} = velData;
            acc{freqInd,currInd} = accData;
            pos{freqInd,currInd} = posData;
            thdArr(freqInd,currInd) = thdMeas;
            currArr(freqInd,currInd) = currPP;
            
    end
    
    
end

%timeVec = time2num(timeVec);    % All these files should have a consistent timeVec

%% Plots

% NOTE - to compare Air vs Ferrofluid, just constrain the 'i' below, repeat
% the execution of this script script for different folders
% Then, manually modify the legends

switch measSet.mode
    case 'chirp'
        figure(1);
        hold on;
        for i = 1:numFiles
            plot(timeVec,filtAccEnv{i});
        end
        hold off
        xlabel('Time (s)');
        ylabel('Acceleration envelope (g)')
        legend(string(split(num2str(currPPData,2))));
        title('Unloaded acceleration envelope to a chirp (differing p-p currents)')
        
        figure(2);
        hold on;
        for i = 1:numFiles
            plot(timeVec,velEnv{i});
        end
        hold off
        xlabel('Time (s)');
        ylabel('Velocity envelope (m/s)')
        legend(string(split(num2str(currPPData,2))));
        title('Unloaded velocity envelope to a chirp (differing p-p currents)')
        
        figure(3);
        hold on;
        for i = 1:numFiles
            plot(Freq,20*log10(abs(TFxyDat{i})));
        end
        hold off
        xlabel('Frequency (Hz)');
        ylabel('Amplitude Response(dB)')
        xlim([0 1000])
        legend(string(split(num2str(currPPData,2))));
        title('Transfer function Stimuli->Actuator Acc (differing currents)')
        
    case 'square'
        figure(1);
        hold on;
        for i = 1:numFiles
            plot(timeVec,filtAcc{i});
        end
        hold off
        xlabel('Time (s)');
        ylabel('Measured Acc (g)')
        xlim(seconds([1.3495 1.3705]))
        legend(string(split(num2str(currPPData,2))));
        title('Dynamic Response to a step in current->Actuator Acc (differing currents)')
        
        figure(4);
        hold on;
        for i = 1:numFiles
            plot(timeVec,pos{i});
        end
        hold off
        xlabel('Time (s)');
        ylabel('Position (mm)')
        %xlim([0 1000])
        legend(string(split(num2str(currPPData,2))));
        title('Dynamic Response to a step in current->Actuator Pos (differing currents)')
        
    case 'sine'
        
        % Specify a frequency, and plot the positions for diff
        % current values
        freqIndPlt = 5;
        figure(4);
        hold on
        for i = 1:length(currTargets)
            plot(timeVec,pos{freqIndPlt,i}*10^6);
        end
        hold off
        xlabel('Time (s)');
        ylabel('Position (um)')
        %xlim([0 1000])
        legend(string(split(num2str(currArr(freqIndPlt,:),2))));
        title(num2str(freqsInterest(freqIndPlt),3)+"Hz Sinusoid (differing currents)")
        
        
        figure(5);
        semilogx(freqsInterest,thdArr);
        xlabel('Frequency (Hz)');
        ylabel('THD (dB)')
        %xlim([0 1000])
        legend(string(split(num2str(currTargets,2))));
        title("Total Harmonic Distortions (differing p-p currents)")
        
        
end