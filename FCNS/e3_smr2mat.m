addpath(genpath('~/TOOLBOXES/Spike-smr-reader'));
gcconv = ImportSMR('~/estropharm3/BEHAV_LOGS/gridC/biometrics/1_gridcells.smr')


ced_mat = load('~/tmp/1_gridcells.mat');
ced_txt = tdfread('~/tmp/1_gridcells_spreadsheet.txt'); % really slow....

ced_mat_alex = load('~/tmp/1_gridcells_alex.mat');


[txt_r, mat_r] = synchronize(ced_txt.x0x221_PULS0x22,ced_mat.V1_gridcells_Ch1.values,'Uniform','Interval',0.01);
mat_r = interp(0.001,ced_txt.x0x221_PULS0x22,0.01,'nearest')

plot(ced_txt.x0x221_PULS0x22);



ced_txt = readtable('~/tmp/1_gridcells_spreadsheet.txt','Delimiter','\t', ...
    'Format','%f\t%d\t%d\t%f\t%f'); 

figure;plot(ced_mat.V1_gridcells_Ch1.values,'color','b');title('CED mat - pulse (ch1)');
figure;plot(ced_txt.x1PULS,'color','r');title('CED txt - pulse (ch1)');
figure;plot(smrread(1).imp.adc,'color','g'); title('smrread - pulse');

figure;plot(ced_mat.V1_gridcells_Ch2.values,'color','b');title('CED mat - resp (ch2)');
figure;plot(ced_txt.x2Resp,'color','r');title('CED txt - resp (ch2)');
figure;plot(smrread(2).imp.adc,'color','g'); title('smrread - resp');


figure;plot(ced_mat.V1_gridcells_Ch1.values(1:60000),'color','b');title('CED mat - pulse (ch1)');
figure;plot(ced_txt.x1PULS(1:60000),'color','r');title('CED txt - pulse (ch1)');



figure;plot(ced_mat.V1_gridcells_Ch2.values(1:60000),'color','b');title('CED mat - resp (ch2)');

figure;plot(ced_txt.x2Resp(1:60000),'color','r');title('CED txt - resp (ch2)');


figure;plot(ced_mat_alex.V1_gridcells_Ch1.values,'color','b');title('CED mat alex - pulse (ch1)');




figure;plot(ced_mat.V1_gridcells_Ch7.values,'color','b');title('CED mat - scanner (ch2)');
figure;plot(ced_txt.x7Scanner,'color','r');title('CED txt - scanner (ch2)');
figure;plot(smrread(3).imp.mrk,'color','g'); title('smrread - scanner');



hold on
plot(ced_txt.x1PULS,'color','r');
title('CED - pulse');
legend('mat','txt');


plot(ced_mat.V1_gridcells_Ch2.values,'color','b');
hold on
plot(ced_txt.x2Resp,'color','r');
title('respiration');
legend('mat','txt');






plot(ced_txt.x0x221_PULS0x22,'color','r');
hold on;
plot(ced_mat.V1_gridcells_Ch1.values,'color','b');
title('CED mat - pulse');
legend('mat','txt');
title('pulse');




plot(ced_txt.x0x222_Resp0x22);
title('CED txt - breathing');
plot(ced_mat.V1_gridcells_Ch2.values);
title('CED txt - breathing');

plot(ced_txt.x0x227_scanner0x22);
title('CED txt - scanner pulse');
plot(ced_mat.V1_gridcells_Ch7.times); %% prob with the scanner pulses in mat file -- 
title('CED txt - scanner pulse');


%% export biometric log files from CED Spike2 as "spreadsheet csv" text files for TAPAS PhysIO Toolbox
log_files     = 'Custom';

% physiological recordings can be entered via a custom data format, i.e.,
% providing one text file per device. The files should contain one
% amplitude value per line. The corresponding sampling interval(s) are
% provided as a separate parameter in the toolbox. 

% 'Custom' expects the logfiles (separate files for cardiac and respiratory)
% to be plain text, with one cardiac (or
% respiratory) sample per row;
% If heartbeat (R-wave peak) events are
% recorded as well, they have to be put
% as a 2nd column in the cardiac logfile
% by specifying a 1; 0 in all other rows
% e.g.:
% 0.2 0
% 0.4 1 <- cardiac pulse event
% 0.2 0
% -0.3 0