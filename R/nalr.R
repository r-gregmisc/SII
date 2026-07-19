calculate_nalr_gain <- function(freq, threshold) {
  # NAL-R formula requires Pure Tone Average (PTA) at 500, 1000, 2000 Hz
  pta_freqs <- c(500, 1000, 2000)
  
  # Find or interpolate thresholds at PTA frequencies
  if (all(pta_freqs %in% freq)) {
    pta_thresh <- threshold[match(pta_freqs, freq)]
  } else {
    pta_thresh <- approx(x = log10(freq), y = threshold, xout = log10(pta_freqs), rule = 2)$y
  }
  
  pta <- mean(pta_thresh, na.rm = TRUE)
  
  # NAL-R X constant
  X <- 0.15 * pta
  
  # NAL-R C correction factors
  c_freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
  c_vals <- c(-17, -8, 1, -1, -2, -2, -2, -2)
  
  # Interpolate C values to the requested frequencies (linear interpolation on log frequency scale)
  c_interp <- approx(x = log10(c_freqs), y = c_vals, xout = log10(freq), rule = 2)$y
  
  # Calculate Real Ear Insertion Gain (REIG)
  # IG = X + 0.31 * HT + C
  ig <- X + 0.31 * threshold + c_interp
  
  # Gain should not be negative for a typical linear prescription
  ig <- pmax(ig, 0, na.rm = TRUE)
  
  return(ig)
}

calculate_open_nl_gain <- function(freq, threshold, input_level) {
  # 1. Base Anchor (For 65 dB SPL input)
  # We use the NAL-R linear formula. NAL-R aggressively cuts low frequencies (-17 dB at 250 Hz). 
  # We just proved that if we flatten this (give more low-frequency gain), the SII DROPS due to 
  # upward spread of masking and level distortion. NAL-R's shape was optimal!
  g_65 <- pmax(0, calculate_nalr_gain(freq, threshold))
  
  # Add a Severe-Loss Booster: NAL-R (half-gain) under-amplifies severe losses.
  # For thresholds > 60 dB HL, we increase the gain ratio slightly.
  g_65 <- g_65 + pmax(0, threshold - 60) * 0.5
  
  # Adaptive High-Frequency Booster:
  # Adding +6 dB blindly causes Level Distortion (rollover) for mild losses where audibility is already 1.0.
  # We scale the HF boost based on the hearing loss. 
  hf_boost_max <- approx(x = log10(c(250, 1000, 4000, 8000)), y = c(0, 0, 6, 6), xout = log10(freq), rule = 2)$y
  hf_scaling <- pmin(1, pmax(0, (threshold - 30) / 30))
  g_65 <- g_65 + (hf_boost_max * hf_scaling)
  # High-Frequency Roll-off (Dead Region & Feedback Protection)
  # Only applies to SLOPING losses. If the loss is relatively flat, we allow the full gain.
  best_low_thresh <- min(threshold[freq <= 1000], na.rm = TRUE)
  
  # Slope factor: 0 if difference < 20 dB, 1 if difference > 40 dB
  slope_factor <- pmax(0, pmin(1, (threshold - best_low_thresh - 20) / 20))
  
  hf_rolloff_freq_scaling <- pmax(0, pmin(1, (freq - 2000) / 2000))
  hf_rolloff_thresh_scaling <- pmax(0, threshold - 80) * 0.8
  
  # Apply roll-off ONLY if it's a sloping loss
  g_65 <- g_65 - (hf_rolloff_freq_scaling * hf_rolloff_thresh_scaling * slope_factor)
  
  # Ensure gain doesn't go below 0, but allow it to exceed 25 dB for flat/severe losses
  g_65 <- pmax(g_65, 0)
  
  # 2. Multi-channel WDRC Pivot
  # We pivot WDRC around the expected band level for normal speech (65 dB overall)
  data("critical", package="SII")
  pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
  
  # 3. Bi-directional Dynamic Range Optimization
  # To match DSL v5.0 targets, we must maximize gain at average speech, 
  # reduce gain for loud speech (to avoid ANSI distortion penalties), 
  # and reduce gain for soft speech (expansion for comfort).
  
  # For inputs > 65 dB, we compress aggressively (CR > 1)
  cr_loud <- 1 + pmax(0, threshold - 20) / 25
  # Clinical Limit: Prevent WDRC from becoming limiting compression (> 3.0) 
  # High CRs destroy the speech envelope and degrade sound quality
  cr_loud <- pmin(cr_loud, 3.0)
  
  # For inputs < 65 dB, we expand (CR < 1)
  cr_soft <- 0.6 
  
  # 4. WDRC interpolation math using ifelse for multi-channel array support
  ig <- ifelse(input_level >= pivot,
               g_65 - (input_level - pivot) * (1 - 1/cr_loud),
               g_65 - (input_level - pivot) * (1 - 1/cr_soft))
  
  # Ensure no negative gain
  ig <- pmax(ig, 0, na.rm = TRUE)
  return(ig)
}

calculate_nal_sspl90 <- function(threshold, gain) {
  # 1. Broad NAL-SSPL90 baseline based on three-frequency PTA equivalents
  # From heuristics: 89 for normal, 107 for 60 dB HL, 139 for 120 dB HL
  base_sspl <- approx(x = c(0, 60, 120), y = c(89, 107, 139), xout = threshold, rule = 2)$y
  
  # 2. Frequency-specific heuristic (Prescribed Gain + Loud Peaks)
  # Loud speech peaks reach ~75 dB SPL, so MPO needs to at least clear this to avoid clipping speech.
  heuristic_mpo <- gain + 75
  
  # 3. Estimated LDL & Safety Margin
  # Estimated LDLs often range around 100 dB SPL for normal hearing, 
  # expanding up to 130-140 dB SPL for profound loss. 
  # We apply the 5 dB safety margin from the heuristics to account for real-ear SPL variations:
  estimated_ldl <- 100 + pmax(0, threshold - 40) * 0.5
  safe_mpo <- estimated_ldl - 5
  
  # Final MPO: Take the heuristic MPO, but cap it at the Safe MPO limit.
  mpo <- pmin(heuristic_mpo, safe_mpo)
  
  # Absolute ceiling (Johnson 2017 PTS Safety Limits)
  # Limit output based on threshold to avoid permanent threshold shift.
  pts_safe_limit <- 105 + pmax(0, threshold - 50) * 0.5
  mpo <- pmin(mpo, pts_safe_limit)
  
  return(mpo)
}
