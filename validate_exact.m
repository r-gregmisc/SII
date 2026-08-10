disp('Starting Exact 1:1 AMT Validation...');
addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
amt_start;

spec_data = csvread('exact_1hz_spectrum.csv', 1, 0);
f = spec_data(:, 1);
lvl = spec_data(:, 2);

HLcf = [250, 500, 1000, 2000, 4000, 8000];
htl = [10, 10, 20, 60, 80, 100];
ohc_prop = 0.65;
HLohcdB0 = min(ohc_prop * htl, 57.6);
HLihcdB0 = max(htl - HLohcdB0, 0);

[Ldn_imp] = chen2011(f, lvl, 'HLcf', HLcf, 'HLohcdB0', HLohcdB0, 'HLihcdB0', HLihcdB0, 'FreeField');
disp(['AMT Octave Monaural Sones: ', num2str(Ldn_imp)]);
