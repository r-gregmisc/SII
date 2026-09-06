# validate_amt_loudness_random.R
# This script generates 250 completely randomized audiogram profiles and input levels,
# evaluates them using the Open-NL C++ engine, and generates an Octave/MATLAB script 
# to run the identical set against AMT bramslow2004 for cross-validation.

library(ggplot2)
library(dplyr)

suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness")), envir = .GlobalEnv))
devtools::load_all(".", quiet=TRUE)

set.seed(42) # For reproducible random samples
n_samples <- 250
aud_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

random_profiles <- list()
test_grid <- data.frame(id = 1:n_samples, level = sample(seq(50, 90, by=1), n_samples, replace=TRUE))

cpp_loudness <- numeric(n_samples)

cat("Generating 250 random profiles and evaluate_random_amt.m...\n")
cat("R C++ evaluation is extremely fast (expected time: < 2 seconds).\n\n")

m_code <- c(
  "% AMT bramslow2004 Random Benchmark for Open-NL Validation",
  "% Run with: octave --no-gui evaluate_random_amt.m",
  "addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');",
  "amt_start;",
  sprintf("fprintf('Evaluating %d random test points using bramslow2004...\\n');", n_samples),
  "fprintf('Expected total time: ~6-8 minutes (depending on CPU).\\n');",
  "fileID = fopen('amt_random_results.csv', 'w');",
  "fprintf(fileID, 'id,level,amt_loudness\\n');",
  "t_start = tic;"
)

for (i in 1:n_samples) {
  if (i %% 25 == 0 || i == 1) {
    cat(sprintf("R Progress: Processed %d / %d random profiles...\n", i, n_samples))
  }
  
  # Generate somewhat realistic random audiogram (preventing 100dB jumps)
  t_raw <- cumsum(rnorm(6, mean=5, sd=15)) 
  t_raw <- t_raw - min(t_raw) # shift to 0
  t_scaled <- round(t_raw / max(t_raw) * runif(1, 20, 100))
  t_scaled <- pmax(0, pmin(100, t_scaled))
  
  lvl <- test_grid$level[i]
  loss <- rep(0, 6)
  
  presc <- open_nl(speech = lvl, threshold = t_scaled, freq = aud_freqs, loss = loss, optimize = FALSE)
  cpp_loudness[i] <- calculate_loudness(presc)$total
  
  aided_spl <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (lvl - 65) + presc$gain
  
  bramslow_freqs <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)
  bramslow_hl <- approx(log10(aud_freqs), t_scaled, log10(bramslow_freqs), rule=2)$y
  bramslow_spl <- approx(log10(aud_freqs), aided_spl, log10(bramslow_freqs), rule=2)$y
  
  freq_str <- paste(bramslow_freqs, collapse = " ")
  lvl_str <- paste(bramslow_spl, collapse = " ")
  hl_str <- paste(bramslow_hl, collapse = " ")
  
  m_code <- c(m_code, 
    sprintf("if %d > 1", i),
    sprintf("  elapsed = toc(t_start);"),
    sprintf("  avg_time = elapsed / (%d - 1);", i),
    sprintf("  eta = avg_time * (%d - %d + 1);", n_samples, i),
    sprintf("  fprintf('Running Random Profile %%d at %%d dB SPL (%%d/%d)... [ETA: %%.1f sec]\\n', %d, %d, %d, eta);", i, n_samples, i, lvl, i),
    "else",
    sprintf("  fprintf('Running Random Profile %%d at %%d dB SPL (%%d/%d)... [ETA: Calculating...]\\n', %d, %d, %d);", i, n_samples, i, lvl, i),
    "end",
    "fs = 32000;",
    "t = (0:(fs*0.25-1))' / fs;", 
    "insig = zeros(length(t), 1);",
    sprintf("freqs = [%s];", freq_str),
    sprintf("levels = [%s];", lvl_str),
    sprintf("hl = [%s];", hl_str),
    "for k = 1:length(freqs)",
    "  A = sqrt(2) * 10^((levels(k) + 10*log10(10) - 94)/20);",
    "  insig = insig + A * sin(2*pi*freqs(k)*t + rand*2*pi);",
    "end",
    "ag_loss = hl;", 
    "res = bramslow2004(insig, fs, 'AGLoss', ag_loss);",
    sprintf("fprintf(fileID, '%%d,%%d,%%f\\n', %d, %d, mean(res.Loudness));", i, lvl)
  )
}
m_code <- c(m_code, "fclose(fileID);")
m_code <- c(m_code, "fprintf('AMT evaluation complete! Total time: %.1f sec\\n', toc(t_start));")
writeLines(m_code, "evaluate_random_amt.m")

test_grid$cpp_loudness <- cpp_loudness
write.csv(test_grid, "cpp_random_results.csv", row.names = FALSE)

cat("\nDone! Generated evaluate_random_amt.m and cpp_random_results.csv.\n")
cat("Next steps:\n")
cat("  1. Run 'octave --no-gui evaluate_random_amt.m' (~6-8 minutes)\n")
cat("  2. Run 'Rscript reproducibility_scripts/plot_random_bland_altman.R' (instant)\n")
