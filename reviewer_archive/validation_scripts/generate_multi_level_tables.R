#!/usr/bin/env Rscript
# ==============================================================================
# Script: generate_multi_level_tables.R
# Purpose: Generate the Johnson & Dillon (2011) performance validation tables
#          for the Open-NL target generation algorithm.
#
# Description:
#   This script calculates the Speech Intelligibility Index (SII) and 
#   Moore & Glasberg (2004) Sones for the 7 standard audiograms (A1-A7) 
#   defined by Johnson & Dillon (2011). It compares NAL-NL2 targets 
#   against Open-NL targets at 50, 65, and 80 dB SPL input levels.
#
#   - SII is calculated using the ANSI S3.5-1997 standard with the 
#     Johnson (2011) smoothed desensitization model.
#   - Loudness (Sones) is calculated using the Bramslow (2004) C++ implementation
#     of the Moore & Glasberg (2004) loudness model for hearing impaired listeners.
#
# Requirements: 
#   - The SII package must be installed and loaded.
#   - The `jd2011_targets` dataset must be available.
#
# Author: Mark
# ==============================================================================

# 1. Load the SII package and dependencies
# Using load_all() to ensure the latest development functions are available.
devtools::load_all(".")
load("data/critical.rda")

# Standard audiometric frequencies used for the 6-band octave calculations
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

# ==============================================================================
# Function: calc_bramslow_sones
# ------------------------------------------------------------------------------
# Calculates the Moore & Glasberg (2004) loudness in sones for a given 
# gain target and hearing profile.
#
# Parameters:
#   gain_tgt     - The prescription gain target to evaluate (numeric vector)
#   threshold    - Audiometric thresholds in dB HL (numeric vector)
#   loss         - Conductive loss component in dB (numeric vector)
#   freqs        - Frequencies corresponding to the threshold vector
#   target_level - The broadband input SPL of the speech signal (e.g., 50, 65, 80)
# ==============================================================================
calc_bramslow_sones <- function(gain_tgt, threshold, loss, freqs = hl_freqs, target_level = 65) {
  # Long-Term Average Speech Spectrum (LTASS) shape normalized to 65 dB SPL
  ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  
  # Ensure the gain target is mapped to the standard 6 octave bands
  if (length(gain_tgt) != 6) {
      gain_tgt <- approx(log10(freqs), gain_tgt, log10(hl_freqs), rule=2)$y
  }

  # Scale input speech to the desired target level (50, 65, or 80)
  input_speech <- ltass_65 + (target_level - 65)
  
  # Calculate aided SPL at the eardrum
  aided_spl <- input_speech + gain_tgt - loss
  
  # ----------------------------------------------------------------------------
  # Interpolate aided SPL across the frequency spectrum to calculate overall SPL
  # ----------------------------------------------------------------------------
  f_half <- seq(0, 24000, by = 0.5); f_half[1] <- 1
  li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
  
  # Extrapolate roll-off (24 dB/octave) below 250 Hz and above 8000 Hz
  li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
  li[f_half > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[f_half > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  overall <- 10 * log10(sum(10^(li/10)) * 0.5)
  
  # Create a denser interpolation (every 10 Hz) for the C++ loudness engine
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
  dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
  dense_l[dense_f > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[dense_f > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  
  # Normalize to perfectly match the overall calculated SPL
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 10))
  dense_l <- dense_l + (overall - current_spl)
  
  # ----------------------------------------------------------------------------
  # Determine Outer Hair Cell (OHC) vs Inner Hair Cell (IHC) damage
  # Following Moore & Glasberg (2004), OHC loss maxes out at 65 dB HL.
  # ----------------------------------------------------------------------------
  sn_loss <- pmax(threshold - loss, 0)
  ohc_loss <- pmin(sn_loss, 65)
  ihc_loss <- pmax(sn_loss - 65, 0)
  
  # Execute the Bramslow (2004) C++ loudness model
  res <- tryCatch({
    calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l, HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss, NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)
  }, error = function(e) { NULL })
  
  if(is.null(res)) return(NA)
  return(res$Ldn)
}

# ==============================================================================
# MAIN SCRIPT EXECUTION
# ==============================================================================

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1 (Mild)", "A2 (Rev Slope)", "A3 (Mod Sloping)", "A4 (Mod-Severe)", "A5 (Profound)", "A6 (Mixed)", "A7 (Conductive)")

cat("| Profile | Input (dB SPL) | Method | SII (Johnson Smoothed) | Sones |\n")
cat("|---|---|---|---|---|\n")

# Iterate over all 7 standard JD2011 audiograms
for (i in 1:7) {
  p <- profiles[i]
  p_name <- profile_names[i]
  
  # Extract the pure-tone audiometric data
  target_data <- jd2011_targets[[p]]
  freqs <- target_data$freq
  threshold_6 <- target_data$threshold
  
  # Construct conductive loss components for A6 (Mixed) and A7 (Pure Conductive)
  loss_6 <- rep(0, 6)
  if (p == "a6") loss_6 <- rep(30, 6)
  if (p == "a7") loss_6 <- rep(50, 6)
  
  # Evaluate at 50 dB (Soft), 65 dB (Average), and 80 dB (Loud) speech levels
  for (lvl in c(50, 65, 80)) {
  
      # 1. Open-NL Target Generation
      onl_res <- open_nl(speech = lvl, threshold = threshold_6, freq = hl_freqs, loss = loss_6)
      onl_gain_6 <- onl_res$gain
      
      # 2. NAL-NL2 Target Generation
      # NAL-NL2 outputs a 19-band array (from 125 Hz to 8000 Hz)
      nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, lvl)
      
      # Map the NAL-NL2 19-band array down to 6 octave bands for head-to-head comparison
      nal_gain_6 <- approx(log10(freqs), nal_gain_19, log10(hl_freqs), rule=2)$y
      
      # 3. Speech Intelligibility Index (SII)
      # Calculate the unamplified normal speech spectrum at the specified input level
      normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(hl_freqs), rule = 2)$y
      overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
      speech_spec <- normal_speech + (lvl - overall_normal)
      
      # Compute SII using the octave method and Johnson (2011) smoothed desensitization
      sii_onl <- sii(speech=speech_spec, threshold=threshold_6, loss=loss_6, freq=hl_freqs, method="octave", transducer="none", custom_gain=onl_gain_6, desensitization="johnson2011_smoothed")$sii
      sii_nal <- sii(speech=speech_spec, threshold=threshold_6, loss=loss_6, freq=hl_freqs, method="octave", transducer="none", custom_gain=nal_gain_6, desensitization="johnson2011_smoothed")$sii
      
      # 4. Loudness (Sones)
      sones_onl <- calc_bramslow_sones(onl_gain_6, threshold_6, loss_6, hl_freqs, lvl)
      sones_nal <- calc_bramslow_sones(nal_gain_6, threshold_6, loss_6, hl_freqs, lvl)
      
      # 5. Output Markdown Table Rows
      cat(sprintf("| %s | %d | NAL-NL2 | %.3f | %.2f |\n", p_name, lvl, sii_nal, sones_nal))
      cat(sprintf("| %s | %d | Open-NL | %.3f | %.2f |\n", p_name, lvl, sii_onl, sones_onl))
  }
}
