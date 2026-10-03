# validate_amt_loudness_bland_altman.R
# This script validates the Open-NL C++ steady-state loudness engine against 
# the canonical bramslow2004 implementation in the Auditory Modeling Toolbox (AMT).

library(ggplot2)
library(dplyr)

suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness", "calculate_open_nl_gain")), envir = .GlobalEnv))
devtools::load_all(".", reset = TRUE)
source("R/sii.R")
source("R/open_nl.R")
source("R/benchmark_targets.R")

profiles <- c("a1", "a2", "a3", "a4", "a5")
levels <- seq(50, 90, by = 5)
aud_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

test_grid <- expand.grid(profile = profiles, level = levels, stringsAsFactors = FALSE)
cpp_loudness <- numeric(nrow(test_grid))

cat("Generating evaluate_amt_bramslow.m...\n")
m_code <- c(
  "% AMT bramslow2004 Benchmark for Open-NL Validation",
  "% Run with: octave --no-gui evaluate_amt_bramslow.m",
  "addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');",
  "amt_start;",
  "fprintf('Evaluating 45 test points using bramslow2004...\\n');",
  "fileID = fopen('amt_bramslow_results.csv', 'w');",
  "fprintf(fileID, 'profile,level,amt_loudness\\n');"
)

for (i in 1:nrow(test_grid)) {
  p <- test_grid$profile[i]
  lvl <- test_grid$level[i]
  
  target_data <- jd2011_targets[[p]]
  threshold <- target_data$threshold
  
  presc <- open_nl(speech = lvl, threshold = threshold, freq = aud_freqs, loss = rep(0, 6), optimize = FALSE)
  gain_tgt <- presc$gain
  
  # C++ calculation
  cpp_loudness[i] <- calculate_loudness(presc)$total
  
  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (lvl - 65)
  aided_spl <- input_speech + gain_tgt
  
  bramslow_freqs <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)
  bramslow_hl <- approx(log10(aud_freqs), threshold, log10(bramslow_freqs), rule=2)$y
  bramslow_spl <- approx(log10(aud_freqs), aided_spl, log10(bramslow_freqs), rule=2)$y
  
  freq_str <- paste(bramslow_freqs, collapse = " ")
  lvl_str <- paste(bramslow_spl, collapse = " ")
  hl_str <- paste(bramslow_hl, collapse = " ")
  
  m_code <- c(m_code, 
    sprintf("fprintf('Running Profile %%s at %%d dB SPL (%%d/45)...\\n', '%s', %d, %d);", p, lvl, i),
    "fs = 32000;",
    "t = (0:(fs*0.25-1))' / fs;", # 250ms signal to speed up bramslow2004
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
    sprintf("fprintf(fileID, '%%s,%%d,%%f\\n', '%s', %d, mean(res.Loudness));", p, lvl)
  )
}
m_code <- c(m_code, "fclose(fileID);")
writeLines(m_code, "evaluate_amt_bramslow.m")

# Save C++ results
test_grid$cpp_loudness <- cpp_loudness
write.csv(test_grid, "cpp_loudness_results.csv", row.names = FALSE)

cat("Generated evaluate_amt_bramslow.m and cpp_loudness_results.csv.\n")
cat("1. Run 'octave --no-gui evaluate_amt_bramslow.m' to generate AMT results.\n")
cat("2. Then run 'Rscript reproducibility_scripts/plot_bland_altman.R' to generate Figure 5.\n")
