library(ggplot2)
library(dplyr)
suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness")), envir = .GlobalEnv))
devtools::load_all(".", quiet=TRUE)
source("R/sii.R")
source("R/open_nl.R")
source("R/benchmark_targets.R")

profiles <- c("a1", "a2", "a3", "a4", "a5")
levels <- seq(50, 90, by = 5)
aud_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

test_grid <- expand.grid(profile = profiles, level = levels, stringsAsFactors = FALSE)
cpp_loudness <- numeric(nrow(test_grid))

cat("Generating evaluate_amt_intense.m...\n")
m_code <- c(
  "% Intensive AMT bramslow2004 Benchmark (2400 sine waves)",
  "addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');",
  "amt_start;",
  "fileID = fopen('amt_intense_results.csv', 'w');",
  "fprintf(fileID, 'profile,level,amt_loudness\\n');"
)

for (i in 1:nrow(test_grid)) {
  p <- test_grid$profile[i]
  lvl <- test_grid$level[i]
  
  target_data <- jd2011_targets[[p]]
  threshold <- target_data$threshold
  
  presc <- open_nl(speech = lvl, threshold = threshold, freq = aud_freqs, loss = rep(0, 6), optimize = FALSE)
  gain_tgt <- presc$gain
  cpp_loudness[i] <- calculate_loudness(presc)$total
  
  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (lvl - 65)
  aided_spl <- input_speech + gain_tgt
  
  # Exact continuous integration from the working script
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
  
  freq_str <- paste(dense_f, collapse = " ")
  lvl_str <- paste(dense_l, collapse = " ")
  
  ag_f <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)
  ag_loss <- approx(x = log10(aud_freqs), y = threshold, xout = log10(ag_f), rule = 2)$y
  hl_str <- paste(ag_loss, collapse = " ")
  
  m_code <- c(m_code, 
    "fflush(stdout);",
    sprintf("fprintf('Processing %%s at %%d dB SPL (%%d/45)...\\n', '%s', %d, %d);", p, lvl, i),
    "fs = 48000;",
    "t = (0:(fs*1.0-1))' / fs;", 
    "insig = zeros(length(t), 1);",
    sprintf("freqs = [%s];", freq_str),
    sprintf("levels = [%s];", lvl_str),
    sprintf("hl = [%s];", hl_str),
    "for k = 1:length(freqs)",
    "  A = sqrt(2) * 10^((levels(k) + 10*log10(10) - 94)/20);",
    "  insig = insig + A * sin(2*pi*freqs(k)*t + rand*2*pi);",
    "end",
    "outs = bramslow2004(insig, fs, 'AGLoss', hl);",
    sprintf("fprintf(fileID, '%%s,%%d,%%f\\n', '%s', %d, mean(outs.Loudness));", p, lvl),
    "fprintf('  -> Result: %.2f sones\\n', mean(outs.Loudness));"
  )
}
m_code <- c(m_code, "fclose(fileID);")
writeLines(m_code, "evaluate_amt_intense.m")

test_grid$cpp_loudness <- cpp_loudness
write.csv(test_grid, "cpp_loudness_intense.csv", row.names = FALSE)
cat("Intense scripts generated. Run Octave, then plot.\n")
