% run_amt_harness.m
% Runs AMT 1.6.0 bramslow2004 stage functions on the inputs from make_cases.R.
% Run from reproducibility_scripts/audmod_validation:
%   octave --no-gui --eval "cases_to_run = 1:5; run_amt_harness"

addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');
amt_start;

fs = 32000; N = 8192;
NoChan = 30; E_Beg = 3; E_End = 32;
RET = [45.0 27.0 13.5 9.0 7.5 7.5 9.0 11.5 12.0 16.0 15.5 12.5 10.0];
AGF = [125 250 500 750 1000 1500 2000 3000 4000 6000 8000 10000 12500];
AGFs_E = f2erbrate(AGF);

E_Bin = zeros(1, N/2);
for j = 1:N/2
  E_Bin(j) = f2erbrate(j*fs/N);
end

cases = dlmread('in/cases_numeric.csv', ',');
if ~exist('cases_to_run', 'var')
  cases_to_run = cases(:, 1)';
end
if ~exist('out', 'dir')
  mkdir('out');
end

for id = cases_to_run
  row = cases(cases(:, 1) == id, :);
  AGLoss = row(2:14)  + RET;
  AG_UCL = row(15:27) + RET;
  P = dlmread(sprintf('in/spec_%d.csv', id))';

  t0 = tic;
  E_0 = bramslow2004_exc0dbspl(N, fs, 'ZWICKA0', false, AGLoss, RET, AGFs_E, NoChan, E_Beg, E_End, E_Bin);
  [~, E_TQ] = bramslow2004_htl(N, fs, 'ZWICKA0', false, AGLoss, RET, AGFs_E, NoChan, E_Beg, E_End, E_Bin);
  E_UCL_dB = bramslow2004_ucl(N, fs, 'ZWICKA0', NoChan, false, AG_UCL, AGLoss, RET, AGFs_E, E_Beg, E_End, E_Bin);

  P = bramslow2004_couplcorr(P, 'freefield', N, fs);
  P = bramslow2004_equloudn(P, 'ZWICKA0', N, fs);
  E_SPL = bramslow2004_erbenergy(P, NoChan, N, fs, true, AGLoss, RET, AGFs_E, E_Beg, E_End);
  [~, E_Vec, HTLL] = bramslow2004_roexfilt(P, E_SPL, N, fs, NoChan, true, AGFs_E, AGLoss, RET, E_Beg, E_End, E_Bin);
  [Nprime, Ldn] = bramslow2004_specloudn(E_Vec, E_0, E_TQ, E_UCL_dB, HTLL, NoChan, E_Beg, E_End, 0);

  M = [(1:NoChan)', E_0(:), E_TQ(:), 10.^(E_UCL_dB(:)/10), E_SPL(:), E_Vec(:), HTLL(:), Nprime(:), repmat(Ldn, NoChan, 1)];

  fid = fopen(sprintf('out/amt_%d.csv', id), 'w');
  fprintf(fid, 'chan,E_0,E_TQ,E_UCL,E_SPL,E_Vector,HTLL,N_prime,Ldn\n');
  fprintf(fid, '%d,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g,%.17g\n', M');
  fclose(fid);

  fprintf('Case %d done in %.1f s, total loudness = %.6f sones\n', id, toc(t0), Ldn);
end
