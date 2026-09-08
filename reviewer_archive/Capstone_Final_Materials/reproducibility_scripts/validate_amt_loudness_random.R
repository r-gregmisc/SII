# validate_amt_loudness_random.R
library(ggplot2)
library(dplyr)
suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness")), envir = .GlobalEnv))
devtools::load_all(".", quiet=TRUE)
set.seed(42)

n_samples <- 50 
aud_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
test_grid <- data.frame(id = 1:n_samples, level = sample(seq(50, 90, by=1), n_samples, replace=TRUE))
cpp_loudness <- numeric(n_samples)

m_code <- c(
  "% AMT glasberg2002 Random Benchmark for Open-NL Validation",
  "addpath('/home/mark/Desktop/amtoolbox-full-1.6.0/amtoolbox-1.6.0');",
  "amt_start;",
  "fileID = fopen('amt_random_results.csv', 'w');",
  "fprintf(fileID, 'id,level,amt_loudness\\n');"
)

for (i in 1:n_samples) {
  t_raw <- cumsum(rnorm(6, mean=5, sd=15)) 
  t_raw <- t_raw - min(t_raw) 
  t_scaled <- round(t_raw / max(t_raw) * runif(1, 20, 100))
  t_scaled <- pmax(0, pmin(100, t_scaled))
  lvl <- test_grid$level[i]
  loss <- rep(0, 6)
  
  presc <- open_nl(speech = lvl, threshold = t_scaled, freq = aud_freqs, loss = loss, optimize = FALSE)
  cpp_loudness[i] <- calculate_loudness(presc)$total
  
  aided_spl <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (lvl - 65) + presc$gain
  
  # For glasberg2002, we generate a highly interpolated dense spectrum (like C++)
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(x = log10(aud_freqs), y = aided_spl, xout = log10(dense_f), rule = 2)$y
  idx_low <- which(dense_f < aud_freqs[1])
  if (length(idx_low) > 0) dense_l[idx_low] <- aided_spl[1] - 24 * log2(aud_freqs[1] / dense_f[idx_low])
  idx_high <- which(dense_f > aud_freqs[length(aud_freqs)])
  if (length(idx_high) > 0) dense_l[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[idx_high] / aud_freqs[length(aud_freqs)])
  
  # AMT Glasberg HL freq knots
  ag_f <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)
  ag_loss <- approx(x = log10(aud_freqs), y = t_scaled, xout = log10(ag_f), rule = 2)$y
  
  freq_str <- paste(dense_f, collapse = " ")
  lvl_str <- paste(dense_l, collapse = " ")
  hl_str <- paste(ag_loss, collapse = " ")
  
  m_code <- c(m_code, 
    sprintf("freqs = [%s];", freq_str),
    sprintf("levels = [%s];", lvl_str),
    sprintf("hl = [%s];", hl_str),
    "res = glasberg2002(levels, freqs, 'hearing_loss', hl);",
    sprintf("fprintf(fileID, '%%d,%%d,%%f\\n', %d, %d, sum(res.specific_loudness) * 0.1);", i, lvl) # E.R.B. step is 0.1 for AMT specific_loudness integration
  )
}
m_code <- c(m_code, "fclose(fileID);")
writeLines(m_code, "evaluate_random_amt.m")
test_grid$cpp_loudness <- cpp_loudness
write.csv(test_grid, "cpp_random_results.csv", row.names = FALSE)
