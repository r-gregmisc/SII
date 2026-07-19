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

calculate_nal_sspl90 <- function(threshold) {
  # Predictive NAL-SSPL90 MPO (Maximum Power Output) calculation
  mpo <- 90 + 0.25 * threshold
  return(mpo)
}
