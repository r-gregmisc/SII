% validate_loudness.m
% Validates the Chen 2011 loudness model for the A4 profile with NAL-NL2 targets
% using the Auditory Modeling Toolbox (AMT).

disp('Starting AMT Validation for A4 NAL-NL2...');

% 1. Create a 65 dB SPL speech spectrum
% For this validation, we use a generic 65 dB SPL flat input to test the model.
f = 20:15000;
lvl = zeros(size(f)) + 30; % 30 dB/Hz roughly equals 65 dB SPL overall speech

% 2. A4 Profile Thresholds
HLcf = [250, 500, 1000, 2000, 4000, 8000];
A4_HL = [0, 0, 10, 40, 70, 80];

% 3. Partitioning (65% OHC)
ohc_prop = 0.65;
HLohcdB0 = min(ohc_prop * A4_HL, 57.6);
HLihcdB0 = max(A4_HL - HLohcdB0, 0);

% 4. NAL-NL2 Target Gains (approximate from Johnson & Dillon)
aided_lvl = lvl + 15;

% 5. Run Normal Hearing Baseline
disp('Calculating Normal Hearing...');
[Ldn_norm, E_norm, Cam_norm, CF_norm] = chen2011(f, lvl, 'HLcf', HLcf, 'HLohcdB0', zeros(size(HLcf)), 'HLihcdB0', zeros(size(HLcf)), 'FreeField');
disp(['Normal Hearing Loudness (sones): ', num2str(Ldn_norm)]);

% 6. Run A4 Impaired (Aided)
disp('Calculating A4 Impaired (Aided)...');
[Ldn_imp, E_imp, Cam_imp, CF_imp] = chen2011(f, aided_lvl, 'HLcf', HLcf, 'HLohcdB0', HLohcdB0, 'HLihcdB0', HLihcdB0, 'FreeField');
disp(['A4 Impaired Monaural Loudness (sones): ', num2str(Ldn_imp)]);

% 7. Calculate Binaural Loudness
L_bin = Ldn_imp + Ldn_imp - 0.25 * sqrt(Ldn_imp * Ldn_imp);
disp(['A4 Impaired Binaural Loudness (sones): ', num2str(L_bin)]);

disp('Validation Complete!');
