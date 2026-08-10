addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
amt_start;

profiles = {'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7'};
sn_htls = {
  [15, 20, 30, 40, 50, 60],
  [60, 50, 40, 30, 20, 15],
  [10, 20, 40, 50, 55, 60],
  [0, 0, 10, 40, 70, 80],
  [10, 10, 20, 60, 80, 100],
  [50, 55, 60, 65, 75, 80],
  [50, 50, 50, 50, 50, 50]
};
abg_list = {
  [0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0],
  [30, 30, 30, 30, 30, 30],
  [50, 50, 50, 50, 50, 50]
};

fid = fopen('octave_sones_a1_a7.csv', 'w');
fprintf(fid, 'Profile,Octave_Sones\n');

for i = 1:length(profiles)
    p = profiles{i};
    sn_htl = sn_htls{i};
    abg = abg_list{i};
    
    % Force constant extrapolation
    HLcf = [20, 250, 500, 1000, 2000, 4000, 8000, 15000];
    % True sensorineural loss is air conduction minus air-bone gap
    sn_htl_true = sn_htl - abg;
    
    sn_htl_ex = [sn_htl_true(1), sn_htl_true, sn_htl_true(end)];
    abg_ex = [abg(1), abg, abg(end)];
    
    ohc_loss = min(0.65 * sn_htl_ex, 57.6);
    ihc_loss = max(sn_htl_ex - ohc_loss, 0);
    
    data = csvread(sprintf('spec_%s.csv', p), 1, 0);
    f = data(:, 1);
    lvl = data(:, 2);
    
    cambin = 0.1;
    flow = 50;
    fhigh = 15000;
    
    [Ldn_imp, E_imp] = chen2011(f, lvl, 'HLcf', HLcf, 'HLohcdB0', ohc_loss, 'HLihcdB0', ihc_loss, 'FreeField', 'cambin', cambin, 'flow', flow, 'fhigh', fhigh);
    
    % Now calculate Moore 2004 specific loudness from E_imp
    % E_imp is already attenuated by IHC loss in chen2011
    
    % Generate CFs
    Cam = (f2erbrate(flow):cambin:f2erbrate(fhigh))';
    CF = 1000*(10.^(Cam/21.4)-1)/4.37;
    
    HLohcdB = interp1(HLcf, ohc_loss, CF, 'linear', 'extrap');
    HLihcdB = interp1(HLcf, ihc_loss, CF, 'linear', 'extrap');
    
    HLohcdB = max(HLohcdB, 0);
    HLihcdB = max(HLihcdB, 0);
    
    g_norm_dB = CF ./ (0.0191*CF + 1.1);
    g_imp_dB = max(g_norm_dB - HLohcdB, 0.1);
    alpha = min(1.0, 0.2 * (g_norm_dB ./ g_imp_dB));
    
    G_norm = 10.^( (CF ./ (0.0191*CF + 1.1)) / 10 );
    A_norm = G_norm * 1.5;
    
    EdB_100 = 100 * ones(length(CF), 1);
    EdB_100_imp = EdB_100 - HLihcdB .* (1 - 0.5./(1+exp(-0.2*((EdB_100-52)-(HLihcdB+20)))));
    E_100_imp = 10.^(EdB_100_imp/10);
    
    E_100_norm = 1e10;
    N_norm_100 = 0.046871 * ( (E_100_norm + A_norm).^0.2 - A_norm.^0.2 );
    
    C_imp = N_norm_100 ./ ( (E_100_imp + A_norm).^alpha - A_norm.^alpha );
    
    N_prime_imp = C_imp .* ( (E_imp + A_norm).^alpha - A_norm.^alpha );
    
    % Unattenuate E to compute normal loudness
    E_imp = max(E_imp, 1e-10);
    EdB = 10*log10(E_imp);
    
    E_unattenuated = 10.^( (EdB + HLihcdB .* (1 - 0.5./(1+exp(-0.2*((EdB-52)-(HLihcdB+20)))))) / 10 );
    N_prime_norm = 0.046871 * ( (E_unattenuated + A_norm).^0.2 - A_norm.^0.2 );
    
    N_prime = N_prime_imp;
    N_prime(E_imp > E_100_imp) = N_prime_norm(E_imp > E_100_imp);
    N_prime = max(0, N_prime);
    
    Ldn = sum(N_prime) * cambin;
    fprintf(fid, '%s,%f\n', p, Ldn);
end
fclose(fid);
