library(SII)
source("R/benchmark_targets.R")
source("R/open_nl.R")
source("R/nalr.R")
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

cat("Multi-Parameter Sensitivity Sweep Variance (65 dB SPL Input)\n")
cat(sprintf("%-7s | %-20s | %-35s\n", "Profile", "Median SII [Min, Max]", "Median Loudness (Sones) [Min, Max]"))
cat(paste(rep("-", 67), collapse=""), "\n")

anchors <- seq(0.40, 0.50, length.out=4)
triggers <- seq(10, 20, length.out=4)
bypasses <- seq(60, 80, length.out=4)
floors <- seq(-20, 0, length.out=4)

profiles <- c("a2", "a4", "a5")
profile_names <- c("A2", "A4", "A5")

for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- target_data$freq
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  
  sii_vals <- numeric()
  sone_vals <- numeric()
  
  for (anc in anchors) {
    for (trig in triggers) {
      for (byp in bypasses) {
        for (flr in floors) {
          presc <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss,
                           optimize = TRUE, enable_severe_booster = TRUE, booster_onset = 60,
                           anchor = anc, slope_trigger = trig, bypass_pta = byp, rs_floor = flr)
                           
          obj <- sii(speech = c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold = threshold, loss = loss, freq = freqs,
                     prescription = presc, method = "octave", 
                     desensitization = FALSE, transducer = "none")
                     
          sii_vals <- c(sii_vals, obj$sii)
          s_val <- calc_amt_loudness(presc$gain, threshold, loss, 65)
          sone_vals <- c(sone_vals, s_val)
          cat(sprintf("Profile %s - anc:%.2f trig:%.1f byp:%.1f flr:%.1f -> SII:%.2f Sones:%.1f\n", 
                      p_name, anc, trig, byp, flr, obj$sii, s_val))
          flush.console()
        }
      }
    }
  }
  
  med_sii <- median(sii_vals)
  min_sii <- min(sii_vals)
  max_sii <- max(sii_vals)
  
  med_sones <- median(sone_vals)
  min_sones <- min(sone_vals)
  max_sones <- max(sone_vals)
  
  cat(sprintf("%-7s | %4.2f [%4.2f, %4.2f] | %4.1f [%4.1f, %4.1f]\n", 
              p_name, med_sii, min_sii, max_sii, med_sones, min_sones, max_sones))
}
