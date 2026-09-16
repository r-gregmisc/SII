suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness", "calculate_open_nl_gain")), envir = .GlobalEnv))

devtools::load_all(".", reset = TRUE)
source("R/sii.R")
source("R/open_nl.R")
source("R/benchmark_targets.R")

cat("Generating evaluate_amt_speech_45.m...\n")
m_code <- c(
  "% AMT Bramslow2004 Benchmark (45 Conditions)",
  "% Run with: octave --no-gui evaluate_amt_speech_45.m",
  "addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');",
  "amt_start;",
  "fs = 48000;",
  "fprintf('Evaluating 45 Combinations (Normal + A1-A7 x NAL-NL2/Open-NL x 3 Levels):\\n');",
  "results_table = {};",
  ""
)

levels     <- c(50, 65, 80)
profiles   <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
aud_freqs  <- c(250, 500, 1000, 2000, 4000, 8000)

build_spectrum <- function(aided_spl, threshold, loss) {
  f_half <- seq(0, 24000, by = 0.5)
  f_half[1] <- 1
  levels_interp <- approx(x = log10(aud_freqs), y = aided_spl, xout = log10(f_half), rule = 2)$y
  idx_low <- which(f_half < aud_freqs[1])
  if (length(idx_low) > 0) levels_interp[idx_low] <- aided_spl[1] - 24 * log2(aud_freqs[1] / pmax(f_half[idx_low], 1))
  idx_high <- which(f_half > aud_freqs[length(aud_freqs)])
  if (length(idx_high) > 0) levels_interp[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[idx_high] / aud_freqs[length(aud_freqs)])
  overall <- 10 * log10(sum(10^(levels_interp/10)) * 0.5)
  
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(x = log10(aud_freqs), y = aided_spl, xout = log10(dense_f), rule = 2)$y
  idx_low <- which(dense_f < aud_freqs[1])
  if (length(idx_low) > 0) dense_l[idx_low] <- aided_spl[1] - 24 * log2(aud_freqs[1] / dense_f[idx_low])
  idx_high <- which(dense_f > aud_freqs[length(aud_freqs)])
  if (length(idx_high) > 0) dense_l[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[idx_high] / aud_freqs[length(aud_freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 10))
  offset <- overall - current_spl
  dense_l <- dense_l + offset
  
  sn_loss <- threshold - loss
  ag_f <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)
  ag_loss <- approx(x = log10(aud_freqs), y = sn_loss, xout = log10(ag_f), rule = 2)$y
  
  list(dense_f = dense_f, dense_l = dense_l, ag_loss = ag_loss)
}

append_octave_code <- function(m_code, p, f, lvl, spec) {
  freq_str <- paste(spec$dense_f, collapse = " ")
  lvl_str <- paste(spec$dense_l, collapse = " ")
  ag_loss_str <- paste(spec$ag_loss, collapse = " ")
  
  c(m_code, 
    sprintf("%% Profile %s - %s @ %d dB", toupper(p), f, lvl),
    sprintf("fprintf('Running %s - %s @ %d dB...\\n');", toupper(p), f, lvl),
    sprintf("inputF = [%s];", freq_str),
    sprintf("inputLdB = [%s];", lvl_str),
    sprintf("ag_loss = [%s];", ag_loss_str),
    "t = (0:(fs-1))' / fs;",
    "insig = zeros(length(t), 1);",
    "for k = 1:length(inputF)",
    "  A = sqrt(2) * 10^((inputLdB(k) + 10*log10(10) - 94)/20);",
    "  insig = insig + A * sin(2*pi*inputF(k)*t + rand*2*pi);",
    "end",
    "outs = bramslow2004(insig, fs, 'AGLoss', ag_loss);",
    "Ldn = mean(outs.Loudness);",
    sprintf("fprintf('  => Sones: %%f\\n', Ldn);"),
    sprintf("results_table(end+1,:) = {'%s', '%s', %d, Ldn};", toupper(p), f, lvl),
    "fflush(stdout);",
    ""
  )
}

# 1. Normal Hearing (3 levels)
for (lvl in levels) {
  cat(sprintf("  Processing NORMAL - Unaided @ %d dB...\n", lvl))
  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (lvl - 65)
  spec <- build_spectrum(input_speech, rep(0, 6), rep(0, 6))
  m_code <- append_octave_code(m_code, "Normal", "Unaided", lvl, spec)
}

# 2. Impaired Hearing (42 combinations)
for (p in profiles) {
  target_data <- jd2011_targets[[p]]
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  formulas <- c("NAL-NL2", "Open-NL")
  for (f in formulas) {
    for (lvl in levels) {
      cat(sprintf("  Processing %s - %s @ %d dB...\n", toupper(p), f, lvl))
      if (f == "Open-NL") {
        presc <- open_nl(speech = lvl, threshold = threshold, freq = aud_freqs, loss = loss)
        gain_tgt <- presc$gain
      } else {
        gain_tgt <- get_nalnl2_v2_target(p, f, target_freqs = aud_freqs, level = lvl)
      }
      
      input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (lvl - 65)
      aided_spl <- input_speech + gain_tgt - loss
      spec <- build_spectrum(aided_spl, threshold, loss)
      m_code <- append_octave_code(m_code, p, f, lvl, spec)
    }
  }
}

m_code <- c(m_code, 
  "fprintf('\\n=== SUMMARY TABLE ===\\n');",
  "fprintf('Profile\\tFormula\\tLevel\\tLoudness\\n');",
  "for i = 1:size(results_table, 1)",
  "  fprintf('%s\\t%s\\t%d\\t%.4f\\n', results_table{i,1}, results_table{i,2}, results_table{i,3}, results_table{i,4});",
  "end",
  ""
)

writeLines(m_code, "evaluate_amt_speech_45.m")
cat("Generated evaluate_amt_speech_45.m successfully!\n")
