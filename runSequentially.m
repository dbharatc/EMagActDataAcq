%% runSequentially.m
% Script to automate the data acquisition for specific programmatically set
% parameters
%
% Written by Bharat Dandu (bharatdandu@ucsb.edu) - 7/17/21

%%

% Make common signal parameter changes directly in the data script. Then
% comment out the lines where the values of the parameters we wish to set
% here are defined
warning('Ensure that you have commented out the portion of DataAcqEMAct.m that sets the parameter being modified here')

%% For chirps

% check and see if the current target code works, i.e., is it linear based
% on varying the swGain. Else you have to tweak that value with some trial
% and error

currTargets = [.1 .2:.2:1 2];

for i = 1:length(currTargets)
    currTarget = currTargets(i);
    DataAcqEMAct;
end

% Do something similar for step resp if the above works well

%% For discrete sines

% freqsInterest = [5 10 20 40 80 160 320 640];
% 
% for i = 1:length(currTargets)
%     measSet.freqIntrst = freqsInterest(i);
%     DataAcqEMAct;
% end
% % Add another loop for the current targets

%% For force

% Use the dc_steps more 

warning('Please push the data we have collected now to its dedicated folder manually');


