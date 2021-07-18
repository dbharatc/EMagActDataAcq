function forceBias = forceBiasMeas(dq,measSet)
% Function which identifies the bias currently experienced by the force
% sensor

zeroSig = zeros(12*measSet.fs,1);   % 12 second long zero signal
outScanData = zeroSig;
[inputDat,~] = readwrite(dq,outScanData);
fn = fieldnames(inputDat);
biasVec = zeros(length(zeroSig),length(measSet.forceCh));
for i = 1:length(measSet.forceCh)
    biasVec(:,i) = inputDat.(fn{i+2});  % There'll be an offset,
    % determine the exact value by looking at structure of inputDat.
    % For ex, Ch 5 will be inputDat.AD1_5, see if we're getting this
end
forceBias = mean(biasVec);
end
