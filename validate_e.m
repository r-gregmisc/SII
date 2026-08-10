addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
amt_start;

data = csvread('exact_1hz_spectrum.csv', 1, 0);
f = data(:, 1);
lvl = data(:, 2);

% Add 20 and 15000 Hz to force constant extrapolation like R's approx(rule=2)
HLcf = [20, 250, 500, 1000, 2000, 4000, 8000, 15000];
sn_htl = [10, 10, 10, 20, 60, 80, 100, 100];
ohc_proportion = 0.65;
HLohcdB0 = min(ohc_proportion * sn_htl, 57.6);
HLihcdB0 = max(sn_htl - HLohcdB0, 0);

% Match R engine parameters
cambin = 0.1;
flow = 50;
fhigh = 15000;

[Ldn_imp, E_imp] = chen2011(f, lvl, 'HLcf', HLcf, 'HLohcdB0', HLohcdB0, 'HLihcdB0', HLihcdB0, 'FreeField', 'cambin', cambin, 'flow', flow, 'fhigh', fhigh);

dlmwrite('octave_excitation.csv', E_imp, 'precision', 15);
fprintf('octave_excitation.csv generated.\n');
