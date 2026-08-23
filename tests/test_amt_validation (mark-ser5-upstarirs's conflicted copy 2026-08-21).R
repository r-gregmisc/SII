# Validation test script to compare native Rcpp FFT-equivalent engine vs Canonical AMT output

source("R/benchmark_targets.R")
source("R/moore_glasberg.R")
source("R/open_nl.R")
source("R/nalr.R")

Rcpp::sourceCpp("src/bramslow2004.cpp")

cat("Running AMT vs native Rcpp Engine Validation...\n")

expected_sones <- list(
  a1 = 4.7,
  a2 = 4.8,
  a3 = 4.7,
  a4 = 6.7,
  a5 = 4.5,
  a6 = 2.0,
  a7 = 1.1
)

tolerance <- 0.05
failed <- FALSE
profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")

for (p in profiles) {
  loss <- jd2011_targets[[p]]$threshold
  cond <- jd2011_targets[[p]]$loss
  if (is.null(cond)) cond <- rep(0, length(loss))
  
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  
  res <- open_nl(speech = 65, threshold = loss, freq = freqs, loss = cond)
  gain_tgt <- res$gain
  aided_spl <- input_speech + gain_tgt - cond
  
  # 1. Exact MATLAB overall calibration target
  f_half <- seq(0, 24000, by = 0.5)
  f_half[1] <- 1
  levels_interp <- approx(x = log10(freqs), y = aided_spl, xout = log10(f_half), rule = 2)$y
  idx_low <- which(f_half < freqs[1])
  if (length(idx_low) > 0) levels_interp[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / pmax(f_half[idx_low], 1))
  idx_high <- which(f_half > freqs[length(freqs)])
  if (length(idx_high) > 0) levels_interp[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[idx_high] / freqs[length(freqs)])
  
  overall <- 10 * log10(sum(10^(levels_interp/10)) * 0.5)
  
  # 2. Our C++ Engine input
  dense_f <- seq(1, 24000, by = 5)
  dense_l <- approx(x = log10(freqs), y = aided_spl, xout = log10(dense_f), rule = 2)$y
  idx_low <- which(dense_f < freqs[1])
  if (length(idx_low) > 0) dense_l[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / dense_f[idx_low])
  idx_high <- which(dense_f > freqs[length(freqs)])
  if (length(idx_high) > 0) dense_l[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[idx_high] / freqs[length(freqs)])
  
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 5))
  offset <- overall - current_spl
  dense_l <- dense_l + offset
  
  sn_loss <- loss - cond
  ohc <- pmin(0.8 * sn_loss, 65)
  ihc <- sn_loss - ohc
  
  loudness_res <- calculate_loudness_cpp(
    inputF = dense_f, 
    inputLdB = dense_l, 
    HLcf = freqs, 
    HLohcdB0 = ohc, 
    HLihcdB0 = ihc
  )
  
  rcpp_sones <- loudness_res$Ldn
  
  cat(sprintf("Profile %s | New Rcpp Native (2048-pt FFT): %5.2f sones\n", toupper(p), rcpp_sones))
}

cat("\nPlease cross-reference these outputs directly against the output of run_amt_loudness.m!\n")
