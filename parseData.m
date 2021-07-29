function procData = parseData(inputDat, measSet)
% Function which handles required data processing for data streams of each
% modality. Do modify the exact channel parameter field name details for
% inputDat as reqd

fn = fieldnames(inputDat);
% Make sure you determine the exact channels to read in inputDat.
% For ex, Ch 5 will be inputDat.AD1_5, see if we're getting this

if measSet.volt
    procData.voltData = inputDat.(fn{1});  % Voltage in volts. Based on some tests, figure out if a voltage divider ckt (or a 10x probe) is reqd
end

if measSet.curr
    procData.currData = inputDat.(fn{2})/.22;  % Current in amps. Measured Voltage across a .22ohm shunt resistor. Ensure correct channel is processed
end

if measSet.ldv
    procData.velData = inputDat.(fn{3})*measSet.ldvScaling/(4*1000);    % velocities in m/s. Make sure names are accurate
    if max(inputDat.(fn{2})) > 3.9    % Throw a potential overrange warning (LDV voltage is supposed to be below 4V)
        warning('Overrange error for LDV')
    end
end

if measSet.force
    rawMeas = zeros(length(inputDat.Time),length(measSet.forceCh));
    
    for i = 1:length(measSet.forceCh)
        rawMeas(:,i) = inputDat.(fn{i+2});  % Raw measurements from the daq
    end
    
    biasRemMeas = rawMeas - measSet.forceBias;  % Remove the bias measurements
    procData.forceData.Fx = biasRemMeas*measSet.MFx';    % Multiply with the scaling matrix
    procData.forceData.Fy = biasRemMeas*measSet.MFy';
    procData.forceData.Fz = biasRemMeas*measSet.MFz';
    
end

if measSet.therm
    ambientT = 22.5;  % Measure ambient temperature with a meter
    scaleFact = 1/.0041276;     % Scale factor based on k-type gradations and amplification. Modify as reqd, will need a brief calibration
    procData.thermData = inputDat.(fn{9})*scaleFact + ambientT;  % Temperature in degrees celcius
end

end