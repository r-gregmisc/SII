% validate_loudness_a5.m
% Validates the Chen 2011 loudness model for the A5 profile with CAMEQ2-HF targets
% to investigate the extreme 60+ sone prediction.

disp('Starting AMT Validation for A5 CAMEQ2-HF...');

% 1. Create a 65 dB SPL speech spectrum (flat approximation for testing)
f = 20:15000;
lvl = zeros(size(f)) + 30; % 30 dB/Hz

% 2. A5 Profile Thresholds (Severe Sloping)
HLcf = [250, 500, 1000, 2000, 4000, 8000];
A5_HL = [10, 10, 20, 60, 80, 100];

% 3. Partitioning (65% OHC)
ohc_prop = 0.65;
HLohcdB0 = min(ohc_prop * A5_HL, 57.6);
HLihcdB0 = max(A5_HL - HLohcdB0, 0);

% 4. CAMEQ2-HF Target Gains for A5
% Interpolate the CAMEQ2-HF insertion gain targets
cameq2_targets = [10, 10, 25, 45, 60, 65];
cameq2_gain = interp1(HLcf, cameq2_targets, f, 'linear', 'extrap');

% Apply gain to input spectrum (preventing negative gain artifacts from extrapolation)
cameq2_gain = max(cameq2_gain, 0);
aided_lvl = lvl + cameq2_gain;

% 5. Run A5 Impaired (Aided)
disp('Calculating A5 Impaired (Aided) with CAMEQ2-HF...');
[Ldn_imp, E_imp, Cam_imp, CF_imp] = chen2011(f, aided_lvl, 'HLcf', HLcf, 'HLohcdB0', HLohcdB0, 'HLihcdB0', HLihcdB0, 'FreeField');
disp(['A5 CAMEQ2-HF Monaural Loudness (sones): ', num2str(Ldn_imp)]);

disp('Validation Complete!');
