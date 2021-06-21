%% DataProcessingEMAct.m
% Script to perform basic data processing on the measurements taken with
% matlab - Slight variation on the prior script used for waveforms exports
%
% Written by Bharat Dandu (bharatdandu@ucsb.edu) - 4/17/21
% Expanded 6/17/21

%fName = "Data/200Hz_2A_pp_3_4_2021.csv";
%load(fName);   % Use for loading a .mat file. Loads
% 'measmnts','measSet', 'srcSig' structures and variables variables
% Double click to load the data file of interest, easier all round. If
% you've just run DataAcq and haven't cleared the workspace, this step
% isn't required either

%% Definitions / manipulations

[b,a] = butter(8,1000/(measSet.fs/2));

currDataFilt = movmean(measmnts.currData,20);       % Current is pretty much the only mandatory measurement
currPP = mean(max(currDataFilt)-min(currDataFilt));

currData = filter(b,a,measmnts.currData);
currData = mean(currData,2);

if measSet.ldv
    
    if ndims(measmnts.velData) == 2  % Lowpass and Collapse to a single channel by averaging across repetitions
        velData = filter(b,a,measmnts.velData);
        velData = mean(velData,2);
    end
    accData = [diff(medfilt1(velData,10))*measSet.fs;0];     % accelerations in m/s^2, divide by 9.8 for units in g
    accDataFilt = movmean(accData,10);
    %accDataFilt = medfilt1(accData,10); % some simple cleanup
    
    posData = cumtrapz(velData)/measSet.fs;    % position in m. NOTE - examine this further
    
    timeVec = measmnts.measTimeVec;
    
end

if measSet.force
    if ndims(measmnts.forceData.Fx) == 2  % Lowpass and Collapse to a single channel by averaging across repetitions
        forceData.Fx = filter(b,a,measmnts.forceData.Fx);
        forceData.Fy = filter(b,a,measmnts.forceData.Fy);
        forceData.Fz = filter(b,a,measmnts.forceData.Fz);
        
        forceData.Fx = mean(forceData.Fx,2);
        forceData.Fy = mean(forceData.Fy,2);
        forceData.Fz = mean(forceData.Fz,2);
    end
end

if measSet.therm
    if ndims(measmnts.therm) == 2  % Lowpass and Collapse to a single channel by averaging across repetitions
        thermData = filter(b,a,measmnts.thermData);
        
        thermData = mean(thermData,2);
    end
end


%% Basic time domain plotting

if measSet.ldv
    
    figure(1)
    plot(timeVec,accDataFilt/9.8,timeVec,currData);
    legend('Measured Acc (g)','Current thru actuator (A)')
    xlabel('Time (s)')
    title("Acceleration of the actuator, "+num2str(measSet.freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p" )
    
end

if measSet.force
    figure(1)
    plot(timeVec,forceData.Fz,timeVec,sqrt(forceData.Fx.^2+forceData.Fy.^2),timeVec,currData);
    legend('Measured axial force (N)','Measured radial force (N)','Current thru actuator (A)')
    xlabel('Time (s)')
    title("Force of the actuator, "+num2str(currPP,'%.2f')+" A p-p" )
end

if measSet.therm
    figure(10)
    plot(timeVec,thermData,timeVec,currData);
    legend('Measured temperature (deg C)','Current thru actuator (A)')
    xlabel('Time (s)')
    title("Heating of the base of the actuator, "+num2str(currPP,'%.2f')+" A p-p" )
end


%% Mode specific stuff

if measSet.ldv
    switch measSet.mode
        case 'sine'
            figure(2)
            plot(timeVec,velData*1000,timeVec,currData);
            legend('Measured Velocity (m,/sec)','Current thru actuator (A)')
            xlabel('Time (s)')
            title("Velocity of the actuator, "+num2str(measSet.freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p" )
            
            figure(3)
            plot(timeVec,detrend(posData)*10^6,timeVec,currData);
            legend('Measured Pos (um)','Current thru actuator (A)')
            xlabel('Time (s)')
            title("Measured position of the actuator, "+num2str(measSet.freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p")
            
            figure(4)
            thd(velData,measSet.fs);    % add an output argument to supress the plot and save the info
            xlim([0 1]);    % Limit the plot to 1kHz
            %%
        case  'chirp'
            figure(2)
            plot(timeVec,velData);
            ylabel('Measured Velocity (m/sec)');
            xlabel('Time (s)')
            title("Velocity of the actuator, "+num2str(currPP,'%.2f')+" A p-p" )
            
            figure(3)
            [TFxy,Freq] = tfestimate(srcSig,accData,[],[],[],measSet.fs);
            plot(Freq,20*log10(abs(TFxy)))
            xlabel('Frequency')
            ylabel('Magnitude response (in db)')
            title("Transfer fn of the actuator, (acceleration) "+num2str(currPP,'%.2f')+" A p-p");
            xlim([0 1000])
            
        case 'square'
            figure(2)
            plot(timeVec,velData,timeVec,currData);
            legend('Measured Velocity (m/sec)','Current thru actuator (A)')
            xlabel('Time (s)')
            title("Velocity of the actuator, "+num2str(measSet.freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p" )
            
            figure(2)
            plot(timeVec,detrend(cumtrapz((velData-mean(velData))/measSet.fs),1)*1000,timeVec,currData);
            legend('Measured Pos (mm)','Current thru actuator (A)')
            xlabel('Time (s)')
            title("Measured position of the actuator, "+num2str(measSet.freqIntrst)+" Hz, "+num2str(currPP,'%.2f')+" A p-p")
    end
    
end

