library(SII)
source("R/benchmark_targets.R")
Rcpp::sourceCpp("src/bramslow2004.cpp")

calc_amt_loudness <- function(gain_tgt, htl, cond, target_level) {
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (target_level - 65)
  aided_spl <- input_speech + gain_tgt - cond
  f_half <- seq(0, 24000, by = 0.5)
  f_half[1] <- 1
  levels_interp <- approx(x = log10(freqs), y = aided_spl, xout = log10(f_half), rule = 2)$y
  idx_low <- which(f_half < freqs[1])
  if (length(idx_low) > 0) levels_interp[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / pmax(f_half[idx_low], 1))
  idx_high <- which(f_half > freqs[length(freqs)])
  if (length(idx_high) > 0) levels_interp[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[idx_high] / freqs[length(freqs)])
  overall <- 10 * log10(sum(10^(levels_interp/10)) * 0.5)
  dense_f <- seq(1, 24000, by = 5)
  dense_l <- approx(x = log10(freqs), y = aided_spl, xout = log10(dense_f), rule = 2)$y
  idx_low <- which(dense_f < freqs[1])
  if (length(idx_low) > 0) dense_l[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / dense_f[idx_low])
  idx_high <- which(dense_f > freqs[length(freqs)])
  if (length(idx_high) > 0) dense_l[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[idx_high] / freqs[length(freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 5))
  offset <- overall - current_spl
  dense_l <- dense_l + offset
  sn_loss <- htl - cond
  ohc <- sn_loss
  ihc <- rep(0, length(sn_loss))
  loudness_res <- calculate_loudness_cpp(
    inputF = dense_f, inputLdB = dense_l, HLcf = freqs, HLohcdB0 = ohc, HLihcdB0 = ihc, Binaural = 0
  )
  return(loudness_res$Ldn)
}

cat("C++ NATIVE Ablation of SD-LFP Heuristic Constraints (65 dB SPL Input)\n")
cat("Generated using the aggressive 60 dB HL booster onset.\n")
cat(sprintf("%-15s | %-24s | %-17s\n", 
    "Profile", "Unconstrained Seed Sones", "SD-LFP Seed Sones"))
cat(paste(rep("-", 62), collapse=""), "\n")

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1 (Mild/Mod)", "A2 (Reverse)", "A3 (Gentle)", "A4 (Steep)", 
                   "A5 (Profound)", "A6 (Mixed)", "A7 (Conductive)")

for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- target_data$freq
  threshold <- target_data$threshold
  
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  presc_uncon <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss, 
                         optimize = FALSE, disable_sdlfp = TRUE, 
                         enable_severe_booster = TRUE, booster_onset = 60)
  
  sones_uncon <- calc_amt_loudness(presc_uncon$gain, threshold, loss, 65)
  
  presc_con <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss, 
                       optimize = FALSE, disable_sdlfp = FALSE, 
                       enable_severe_booster = TRUE, booster_onset = 60)
  
  sones_con <- calc_amt_loudness(presc_con$gain, threshold, loss, 65)
  
  cat(sprintf("%-15s | %24.1f | %17.1f\n", 
              p_name, sones_uncon, sones_con))
}
