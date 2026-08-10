disp('Starting AMT Validation against Open-NL R Engine...');
addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
amt_start;

f = 20:15000;

% Load EXACT speech spectrum from R
spec_data = csvread('speech_spectrum_65.csv', 1, 0);
spec_freq = spec_data(:, 1);
spec_lvl = spec_data(:, 2);
lvl = interp1(spec_freq, spec_lvl, f, 'linear', 'extrap');
lvl = max(lvl, -20); % prevent crazy negative extrapolation

HLcf = [250, 500, 1000, 2000, 4000, 8000];

profiles = {'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7'};
HL_data = [
  15, 20, 30, 40, 50, 60;
  60, 50, 40, 30, 20, 15;
  10, 20, 40, 50, 55, 60;
   0,  0, 10, 40, 70, 80;
  10, 10, 20, 60, 80, 100;
  50, 55, 60, 65, 75, 80;
  50, 50, 50, 50, 50, 50;
];
r_sones = [6.5, 3.9, 5.3, 11.9, 7.7, 3.6, 10.3];
data = csvread('opennl_targets_65.csv', 1, 1);

fprintf('\n| Profile | R Engine (Sones) | AMT Octave (Sones) | Absolute Error (Delta) |\n');
fprintf('|---|---|---|---|\n');

[Ldn_nh] = chen2011(f, lvl, 'HLcf', HLcf, 'HLohcdB0', zeros(1,6), 'HLihcdB0', zeros(1,6), 'FreeField');
fprintf('| Normal Hearing | 18.60 | %.2f | %.2f |\n', Ldn_nh, abs(18.6 - Ldn_nh));

for i = 1:7
    htl = HL_data(i, :);
    ohc_prop = 0.65;
    HLohcdB0 = min(ohc_prop * htl, 57.6);
    HLihcdB0 = max(htl - HLohcdB0, 0);
    
    target_gain = data(i, :);
    gain = interp1(HLcf, target_gain, f, 'linear', 'extrap');
    gain = max(gain, 0);
    aided_lvl = lvl + gain;
    
    [Ldn_imp] = chen2011(f, aided_lvl, 'HLcf', HLcf, 'HLohcdB0', HLohcdB0, 'HLihcdB0', HLihcdB0, 'FreeField');
    err = abs(r_sones(i) - Ldn_imp);
    fprintf('| %s (Open-NL) | %.2f | %.2f | %.2f |\n', profiles{i}, r_sones(i), Ldn_imp, err);
end
disp('Validation Complete!');
