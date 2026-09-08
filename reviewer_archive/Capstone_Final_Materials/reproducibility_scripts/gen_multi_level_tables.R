#!/usr/bin/env Rscript
# Force load from the SII-github source directory regardless of where this script is sourced from
pkg_root <- "/home/mark/Development/SII-github"

# Fully unload any previously installed SII package, then reload from source
tryCatch(pkgload::unload("SII"), error = function(e) NULL)
devtools::load_all(pkg_root, reset = TRUE)

# Force-source the key R files into the GLOBAL environment so they shadow
# any stale installed package version in the search path.
source(file.path(pkg_root, "R/nalr.R"), local = FALSE)
source(file.path(pkg_root, "R/open_nl.R"), local = FALSE)
source(file.path(pkg_root, "R/sii.R"), local = FALSE)

load(file.path(pkg_root, "data/critical.rda"))

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

calc_bramslow_sones <- function(gain_tgt, threshold, loss, freqs = hl_freqs, target_level = 65) {
  # Simple LTASS shape
  ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  
  # Ensure gain_tgt is mapped to 6 bands
  if (length(gain_tgt) != 6) {
      gain_tgt <- approx(log10(freqs), gain_tgt, log10(hl_freqs), rule=2)$y
  }

  input_speech <- ltass_65 + (target_level - 65)
  aided_spl <- input_speech + gain_tgt - loss
  
  f_half <- seq(0, 24000, by = 0.5); f_half[1] <- 1
  li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
  li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
  li[f_half > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[f_half > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  overall <- 10 * log10(sum(10^(li/10)) * 0.5)
  
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
  dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
  dense_l[dense_f > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[dense_f > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 10))
  dense_l <- dense_l + (overall - current_spl)
  
  sn_loss <- pmax(threshold - loss, 0)
  ohc_loss <- pmin(sn_loss, 65)
  ihc_loss <- pmax(sn_loss - 65, 0)
  
  res <- tryCatch({
    calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l, HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss, NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)
  }, error = function(e) { NULL })
  
  if(is.null(res)) return(NA)
  return(res$Ldn)
}

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1 (Mild)", "A2 (Rev Slope)", "A3 (Mod Sloping)", "A4 (Mod-Severe)", "A5 (Profound)", "A6 (Mixed)", "A7 (Conductive)")

cat("| Profile | Input (dB SPL) | Method | ANSI SII | Effective SII | Sones |\n")
cat("|---|---|---|---|---|---|\n")

for (i in 1:7) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- target_data$freq
  threshold_6 <- target_data$threshold
  loss_6 <- rep(0, 6)
  if (p == "a6") loss_6 <- rep(30, 6)
  if (p == "a7") loss_6 <- rep(50, 6)
  
  # For each level
  for (lvl in c(50, 65, 80)) {
      # Open-NL expects 6 thresholds directly, it will interpolate to 21 internally if needed.
      onl_res <- open_nl(speech = lvl, threshold = threshold_6, freq = hl_freqs, loss = loss_6)
      onl_gain_6 <- onl_res$gain
      
      # NAL-NL2 (Using the supplied targets from jd2011_targets, which is length 19)
      nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, lvl)
      # Map it down to 6 bands for SII and Loudness
      nal_gain_6 <- approx(log10(freqs), nal_gain_19, log10(hl_freqs), rule=2)$y
      
      # SII
      normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(hl_freqs), rule = 2)$y
      overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
      speech_spec <- normal_speech + (lvl - overall_normal)
      
      ansi_sii_onl <- sii(speech=speech_spec, threshold=threshold_6, loss=loss_6, freq=hl_freqs, method="octave", transducer="none", custom_gain=onl_gain_6, desensitization="none")$sii
      ansi_sii_nal <- sii(speech=speech_spec, threshold=threshold_6, loss=loss_6, freq=hl_freqs, method="octave", transducer="none", custom_gain=nal_gain_6, desensitization="none")$sii
      
      eff_sii_onl <- sii(speech=speech_spec, threshold=threshold_6, loss=loss_6, freq=hl_freqs, method="octave", transducer="none", custom_gain=onl_gain_6, desensitization="johnson2011_complete")$sii
      eff_sii_nal <- sii(speech=speech_spec, threshold=threshold_6, loss=loss_6, freq=hl_freqs, method="octave", transducer="none", custom_gain=nal_gain_6, desensitization="johnson2011_complete")$sii
      
      # Sones
      sones_onl <- calc_bramslow_sones(onl_gain_6, threshold_6, loss_6, hl_freqs, lvl)
      sones_nal <- calc_bramslow_sones(nal_gain_6, threshold_6, loss_6, hl_freqs, lvl)
      
      cat(sprintf("| %s | %d | NAL-NL2 | %.3f | %.3f | %.2f | Gain: %.1f, %.1f, %.1f, %.1f, %.1f, %.1f |\n", p_name, lvl, ansi_sii_nal, eff_sii_nal, sones_nal, nal_gain_6[1], nal_gain_6[2], nal_gain_6[3], nal_gain_6[4], nal_gain_6[5], nal_gain_6[6]))
      cat(sprintf("| %s | %d | Open-NL | %.3f | %.3f | %.2f | Gain: %.1f, %.1f, %.1f, %.1f, %.1f, %.1f |\n", p_name, lvl, ansi_sii_onl, eff_sii_onl, sones_onl, onl_gain_6[1], onl_gain_6[2], onl_gain_6[3], onl_gain_6[4], onl_gain_6[5], onl_gain_6[6]))
  }
}
