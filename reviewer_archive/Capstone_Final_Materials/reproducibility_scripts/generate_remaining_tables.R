devtools::load_all(".", quiet=TRUE)
source("R/benchmark_targets.R")
source("R/open_nl.R")
source("R/nalr.R")
Rcpp::sourceCpp("src/bramslow2004.cpp")

calc_amt_loudness_cpp <- function(gain_tgt, htl, cond, target_level) {
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

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

cat("\n### Table II Markdown Output (Seeds):\n")
for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  # Unconstrained (disable_sdlfp=TRUE)
  seed_unconstrained <- calculate_open_nl_gain(freq=freqs, threshold=threshold, input_level=65, loss=loss, enable_severe_booster=TRUE, booster_onset=60, disable_sdlfp=TRUE)
  obj_raw_unconstrained <- sii(speech=c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold=threshold, loss=loss, freq=freqs, custom_gain=seed_unconstrained, method="octave", transducer="none", desensitization=FALSE)
  sones_unconstrained <- calc_amt_loudness_cpp(seed_unconstrained, threshold, loss, 65)

  # Constrained (disable_sdlfp=FALSE)
  seed_constrained <- calculate_open_nl_gain(freq=freqs, threshold=threshold, input_level=65, loss=loss, enable_severe_booster=TRUE, booster_onset=60, disable_sdlfp=FALSE)
  obj_raw_constrained <- sii(speech=c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold=threshold, loss=loss, freq=freqs, custom_gain=seed_constrained, method="octave", transducer="none", desensitization=FALSE)
  sones_constrained <- calc_amt_loudness_cpp(seed_constrained, threshold, loss, 65)

  cat(sprintf("| %s | %.2f | %.1f | %.2f | %.1f |\n", p_name, obj_raw_unconstrained$sii, sones_unconstrained, obj_raw_constrained$sii, sones_constrained))
}


cat("\n### Table VII Markdown Output:\n")
cat("| Profile | Formula | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |\n")
cat("|---|---|---|---|---|---|---|---|\n")
for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  nalnl2_tgt <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, 65)
  opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  
  cat(sprintf("| %s | NAL-NL2 | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n", 
              p_name, nalnl2_tgt[1], nalnl2_tgt[2], nalnl2_tgt[3], 
              nalnl2_tgt[4], nalnl2_tgt[5], nalnl2_tgt[6]))
              
  cat(sprintf("|  | Open-NL | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n", 
              opennl_tgt$gain[1], opennl_tgt$gain[2], opennl_tgt$gain[3], 
              opennl_tgt$gain[4], opennl_tgt$gain[5], opennl_tgt$gain[6]))
}
