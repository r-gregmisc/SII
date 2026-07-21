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

calculate_open_nl_gain <- function(freq, threshold, input_level, gender = "male", experience = "experienced", config = "bilateral", age = "adult", coupling = "custom_occluded", module = "standard") {
  # 0. Minimal Hearing Loss (MHL) Module Bypass
  # If the patient has near-normal hearing (PTA <= 25) and selects the MHL module,
  # we completely bypass the standard WDRC compensation formula.
  pta_4 <- mean(threshold[freq %in% c(500, 1000, 2000, 4000)], na.rm = TRUE)
  if (module == "mhl" && !is.na(pta_4) && pta_4 <= 25) {
    # MHL applies a flat 3-5 dB insertion gain above 1kHz to access SNR features,
    # tapering strictly to 0 dB in the low frequencies.
    mhl_gain <- approx(x = c(250, 500, 1000, 2000, 4000, 8000), 
                       y = c(0, 0, 3, 5, 5, 5), xout = freq, rule = 2)$y
                       
    # Linear amplification for speech inputs up to 65 dB SPL
    data("critical", package="SII")
    pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
    ct_band <- pivot + 5 # Set CT slightly above normal speech
    
    g_ct <- mhl_gain
    cr_loud <- 1.5 # Gentle compression for loud inputs to prevent discomfort
    
    ig <- ifelse(input_level <= ct_band,
                 g_ct,
                 g_ct - (input_level - ct_band) * (1 - 1/cr_loud))
    return(ig)
  }
  
  # 1. Base Anchor (For 65 dB SPL input)
  # We use a frequency-specific half-gain anchor decoupled from broadband PTA, similar to NAL-NL2 and DSL.
  # This prevents normal low-frequency hearing from artificially dragging down high-frequency gain.
  c_freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
  
  # Soften the harsh low-frequency penalties (-17, -8) of the original NAL-R 
  # to improve tonal balance and warmth, similar to the evolution of NAL-NL2.
  # We have globally bumped these by +2 to +3 dB to resolve under-amplification compared to NAL/DSL.
  if (experience == "new") {
    # New users get a very warm, comfortable profile (less low penalty, more high compression)
    c_vals <- c(-3, +2, +3, +0, -2, -2, -2, -2)
    base_mult <- 0.40
  } else if (experience == "power") {
    # Power users tolerate maximum sharpness for SII efficiency and maximum gain
    c_vals <- c(-8, -1, +3, +1, +0, +0, +0, +0)
    base_mult <- 0.50
  } else {
    # Experienced users prefer a balanced profile with comfortable loudness (0.45 multiplier)
    c_vals <- c(-8, -1, +3, +1, +0, +0, +0, +0)
    base_mult <- 0.45
  }
  
  c_interp <- approx(x = log10(c_freqs), y = c_vals, xout = log10(freq), rule = 2)$y
  # 1a. Reverse Slope Correction
  # Standard linear formulas apply massive low-frequency penalties (c_vals = -17 dB at 250 Hz) 
  # because they assume typical sloping losses where low frequencies are normal.
  # For reverse slope losses, this over-penalizes and results in 0 dB gain.
  # We neutralize this negative penalty so the low frequencies become audible.
  low_thresh_mean <- mean(threshold[freq <= 1000], na.rm = TRUE)
  high_thresh_mean <- mean(threshold[freq >= 2000], na.rm = TRUE)
  reverse_slope_diff <- pmax(0, low_thresh_mean - high_thresh_mean)
  
  if (reverse_slope_diff > 0) {
    # If it's a reverse slope, we neutralize the c_vals negative constants 
    # proportionally to how steep the reverse slope is.
    neutralize_factor <- pmin(1, reverse_slope_diff / 30)
    c_interp <- c_interp + neutralize_factor * pmax(0, -c_interp)
  }
  
  # 1b. Steep Slope Knee Correction (e.g. A-4)
  # For steeply sloping losses, upward spread of masking is a severe problem.
  # We identify the "knee" (where hearing is normal/mild but drops off steeply afterwards)
  # and heavily penalize gain there to prevent the low/mid frequencies from masking the highs.
  # We also boost the high frequencies to pull them out of the slope.
  steep_slope_diff <- pmax(0, high_thresh_mean - low_thresh_mean)
  
  # 1c. Preliminary Dead Region Detection (to prevent over-boosting dead zones)
  hf_dead_idx <- which(threshold >= 90 & freq >= 1000)
  f_e_hf <- if (length(hf_dead_idx) > 0) freq[hf_dead_idx[1]] else Inf
  
  lf_dead_idx <- which(threshold >= 80 & freq <= 1000)
  f_e_lf <- if (length(lf_dead_idx) > 0) freq[lf_dead_idx[length(lf_dead_idx)]] else -Inf
  
  if (steep_slope_diff > 30) {
    steep_factor <- pmin(1, (steep_slope_diff - 30) / 30)
    
    # Penalize around the knee (500 - 1500 Hz) to prevent masking
    knee_penalty <- steep_factor * 6 # Up to 6 dB reduction
    # Bell curve weighting around 1000 Hz
    knee_weight <- pmax(0, 1 - abs(log10(freq) - log10(1000)) / log10(2))
    
    # Boost the highs (>= 2000 Hz) to restore audibility
    high_boost <- steep_factor * 6 # Up to 6 dB boost
    # Disable the high boost if the frequency is inside a high-frequency dead region
    high_boost_vec <- ifelse(freq >= f_e_hf, 0, high_boost)
    
    # Fades in from 1500 Hz upwards
    high_weight <- pmax(0, pmin(1, (log10(freq) - log10(1500)) / log10(2.5)))
    
    c_interp <- c_interp - (knee_penalty * knee_weight) + (high_boost_vec * high_weight)
  }
  
  # Use the dynamically selected base multiplier based on user experience.
  # This globally sets the 65 dB SPL anchor to match user comfort vs audibility needs.
  g_65 <- pmax(0, base_mult * threshold + c_interp)
  
  # Add a Severe-Loss Booster: NAL-R (half-gain) under-amplifies severe losses.
  # For thresholds > 60 dB HL, we increase the gain ratio slightly.
  # Cap the booster to a maximum of 10 dB to prevent mid-frequency spikes.
  # Taper the booster in the mid frequencies (1000-2000 Hz) for better loudness comfort.
  slb_raw <- pmax(0, threshold - 60) * 0.5
  slb_raw <- pmin(slb_raw, 15) # Cap at 15 dB
  
  # Disable the Severe Loss Booster for frequencies inside a dead region.
  # Pumping massive gain into a dead region just causes distortion without benefit.
  slb_raw[freq >= f_e_hf | freq <= f_e_lf] <- 0
  
  # Taper SLB in mid frequencies (1000-2000 Hz)
  mid_taper <- pmax(0, pmin(1, 1 - abs(freq - 1500) / 1000)) # 1 at 1500, 0 at 500 and 2500
  slb_final <- slb_raw * (1 - 0.5 * mid_taper)
  
  g_65 <- g_65 + slb_final
  
  # High-Frequency Desensitization Roll-off (Smooth Soft-Compression)
  # Instead of a harsh penalty or hard cap (which causes jagged artifacts),
  # we softly compress any insertion gain that exceeds 25 dB in the high frequencies.
  
  # Determine if there is a sloping component (difference between high and low thresholds)
  best_low_thresh <- min(threshold[freq <= 1000], na.rm = TRUE)
  # We completely relax this penalty (triggering at 25 dB diff instead of 5) 
  # so that A-4 gets MORE high frequency gain, not less!
  slope_factor <- pmax(0, pmin(1, (threshold - best_low_thresh - 25) / 20))
  
  # Weighting factor that fades in from 2000 Hz to 4000 Hz
  hf_weight <- pmax(0, pmin(1, (freq - 2000) / 2000)) 
  
  # We dynamically scale the gain limit so severe losses can still get the amplification they need.
  # Lifted base limit from 25 to 30 dB to prevent underamplification of steep slopes
  gain_limit <- 30 + pmax(0, threshold - 60) * 0.4
  excess_gain <- pmax(0, g_65 - gain_limit)
  
  # Compress the excess (2:1 ratio instead of 4:1 to allow more gain through)
  compressed_excess <- excess_gain * 0.50 
  
  # Apply the smooth compression only to the high frequencies of a sloping loss
  g_65 <- g_65 - (hf_weight * slope_factor * (excess_gain - compressed_excess))
  
  # 1e. NAL-NL3 Bandwidth Roll-off
  # Reduced emphasis on using low-frequency (<= 250 Hz) and very high-frequency (>= 6 kHz) gain
  bw_rolloff <- approx(x = c(250, 500, 1000, 2000, 4000, 6000, 8000), 
                       y = c(0.7, 1.0, 1.0, 1.0, 1.0, 0.8, 0.5), xout = freq, rule = 2)$y
  g_65 <- g_65 * bw_rolloff
  
  # Ensure gain doesn't go below 0
  g_65 <- pmax(g_65, 0)
  
  # 1d. Cochlear Dead Region Roll-off
  # Based on Moore (2001, 2004) and Vickers et al. (2001).
  # If a dead region is detected, amplifying beyond its viable boundary provides no speech 
  # intelligibility benefit and causes distortion/feedback.
  
  # High-Frequency Dead Region (HFDR)
  if (length(hf_dead_idx) > 0) {
    hf_cutoff <- 1.7 * f_e_hf
    
    # Apply a steep penalty of 30 dB per octave above the cutoff
    hf_dr_penalty <- pmax(0, log2(freq / hf_cutoff)) * 30
    g_65 <- pmax(0, g_65 - hf_dr_penalty)
  }
  
  # Low-Frequency Dead Region (LFDR)
  if (length(lf_dead_idx) > 0) {
    lf_cutoff <- 0.57 * f_e_lf
    
    # Apply a steep penalty of 30 dB per octave below the cutoff
    lf_dr_penalty <- pmax(0, log2(lf_cutoff / freq)) * 30
    g_65 <- pmax(0, g_65 - lf_dr_penalty)
  }
  
  # 2. Multi-channel WDRC Pivot
  # We pivot WDRC around the expected band level for normal speech (65 dB overall)
  data("critical", package="SII")
  pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
  
  # 3. Bi-directional Dynamic Range Optimization (WDRC)
  # To match evidence-based targets (e.g., Keidser et al., NAL-NL2), we scale the Compression Ratio (CR).
  
  # Moderate (40-65 HL): CR climbs from 1.5 to ~2.5
  # We steepen the CR curve to match the high compression of NAL-NL2 and DSL, 
  # which dramatically boosts gain for 55 dB SPL soft speech.
  base_cr <- 1 + pmax(0, threshold - 20) / 25
  
  # Severe/Profound (>65 HL): CR actually REDUCES back toward linear.
  # Patients with severe loss prefer lower compression (1:1 to 2:1) to preserve the temporal envelope.
  severe_penalty <- pmax(0, threshold - 65) / 30
  
  # Frequency dependence for severe loss:
  # Low frequencies (<1000 Hz) strongly prefer linear (CR ~1.0).
  # High frequencies can tolerate more compression (CR ~1.5 - 2.0).
  freq_modifier <- pmax(0, pmin(1, (freq - 500) / 2500)) # 0 at 500Hz, 1 at >=3000Hz
  adjusted_penalty <- severe_penalty * (1.5 - 0.5 * freq_modifier)
  
  cr_loud <- base_cr - adjusted_penalty
  
  # Clinical Limits: Ensure CR stays between 1.0 (linear) and a strict 2.5 maximum (NAL-NL3 standard).
  cr_loud <- pmax(1.0, pmin(cr_loud, 2.5))
  
  # 3.5 Variable Compression Threshold (DSL v5.0a Philosophy)
  # Instead of a fixed low knee-point, the CT increases with hearing loss severity.
  ct_overall <- approx(x = c(20, 50, 80, 100), y = c(35, 45, 60, 70), xout = threshold, rule = 2)$y
  
  # ct_overall is the OVERALL speech level CT. We must convert it to a BAND level CT.
  # Since 'pivot' is the band level for 65 dB SPL overall speech, 
  # the band level CT is simply pivot + (ct_overall - 65).
  ct_band <- pivot + (ct_overall - 65)
  
  # 3.8 Comfort in Noise (CIN) Module
  if (module == "cin") {
    # NAL-NL3 CIN Module aims to reduce loudness for high input levels
    # while preserving speech intelligibility (soft/average inputs).
    # We increase the compression ratio significantly for loud sounds.
    cr_loud <- pmax(cr_loud, 2.0)
    
    # We lower the WDRC pivot / CT so compression kicks in earlier.
    ct_band <- ct_band - 10
  }
  
  # The target gain 'g_65' is prescribed for an input level of 'pivot'.
  # If CT > pivot, the pivot is in the linear region, so the linear gain is simply g_65.
  # If CT <= pivot, the pivot is in the WDRC region. We calculate the gain at CT by climbing the WDRC slope backward.
  g_ct <- ifelse(ct_band > pivot,
                 g_65, 
                 g_65 + (pivot - ct_band) * (1 - 1/cr_loud))
  
  # 4. Multistage I/O calculation (Linear below CT, WDRC above CT)
  ig <- ifelse(input_level <= ct_band,
               g_ct,
               g_ct - (input_level - ct_band) * (1 - 1/cr_loud))
  
  # 5. Apply Empirical Demographic Adjustments (Keidser et al., 2012)
  adjustment <- 0
  
  # Gender: Females prefer ~1.5 dB less gain
  if (gender == "female") {
    adjustment <- adjustment - 1.5
  }
  # Age / Acquired-Loss Penalty (DSL v5.0a Philosophy)
  # Adults prefer less gain than children, particularly for mild-to-moderate losses.
  # This difference shrinks as the hearing loss becomes more severe.
  if (age == "child") {
    # We apply a dynamic boost for children relative to the adult baseline.
    # ~7 dB for mild/moderate losses, tapering to ~3 dB for severe losses.
    child_boost <- approx(x = c(20, 50, 80, 100), y = c(7, 7, 3, 1), xout = threshold, rule = 2)$y
    adjustment <- adjustment + child_boost
  }
  # Configuration: Unilateral fittings require ~3 dB more gain due to lack of binaural summation
  if (config == "unilateral") {
    adjustment <- adjustment + 3.0
  }
  
  # Experience: New users with PTA > 40 prefer less gain (up to 6 dB less)
  if (experience == "new") {
    pta_val <- mean(threshold[freq %in% c(500, 1000, 2000)], na.rm = TRUE)
    if (!is.na(pta_val) && pta_val > 40) {
      exp_penalty <- (pta_val - 40) * 0.3
      exp_penalty <- pmin(exp_penalty, 6.0)
      adjustment <- adjustment - exp_penalty
    }
  }
  
  ig <- ig + adjustment
  
  # 6. Apply Acoustic Coupling / Vent Effect (Caporali et al., 2019)
  # Simulated Real-Ear Aided Response (REAR) by subtracting leakage.
  if (coupling != "custom_occluded") {
    ve_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
    if (coupling == "open_dome") {
      ve_loss <- c(-35, -28, -15, -2, 0, 0)
    } else if (coupling == "tulip_dome") {
      ve_loss <- c(-25, -18, -5, 0, 0, 0)
    } else if (coupling == "double_dome") {
      ve_loss <- c(-20, -10, 0, 0, 0, 0)
    } else {
      ve_loss <- c(0, 0, 0, 0, 0, 0)
    }
    
    ve_interp <- approx(x = log10(ve_freqs), y = ve_loss, xout = log10(freq), rule = 2)$y
    ig <- ig + ve_interp
  }
  
  # 7. Final Cross-Channel Frequency Smoothing
  # Atypical audiograms (like "cookie-bites") can produce jagged, V-shaped frequency responses
  # that cause distortion across channels. We apply a 3-point moving average to smooth the final curve.
  if (length(ig) > 2) {
    ig_smoothed <- ig
    for (i in 2:(length(ig) - 1)) {
      ig_smoothed[i] <- (ig[i - 1] + ig[i] + ig[i + 1]) / 3.0
    }
    ig <- ig_smoothed
  }
  
  # Ensure gain doesn't go below 0
  ig <- pmax(ig, 0, na.rm = TRUE)
  return(ig)
}

calculate_nal_sspl90 <- function(threshold, gain, ldl = NULL) {
  # NAL SSPL90 rule (Maximum Power Output)
  # Derived from Dillon (2012) and NAL guidelines for avoiding discomfort
  
  # 1. Base SSPL90 for normal hearing is roughly 90-100 dB SPL
  # 2. SSPL90 increases by roughly 0.5 dB for every 1 dB of hearing loss above 40 dB HL
  heuristic_mpo <- 100 + pmax(0, threshold - 40) * 0.5
  
  # 3. Estimated LDL & Safety Margin
  # Estimated LDLs often range around 100 dB SPL for normal hearing, 
  # expanding up to 130-140 dB SPL for profound loss. 
  estimated_ldl_spl <- 100 + pmax(0, threshold - 40) * 0.5
  
  if (!is.null(ldl) && length(ldl) == length(threshold)) {
    # If explicit LDL is provided (in HL), convert to approximate SPL (HL + 10)
    # Use estimated LDL if measured LDL is NA
    ldl_spl <- ifelse(is.na(ldl), estimated_ldl_spl, ldl + 10)
  } else {
    ldl_spl <- estimated_ldl_spl
  }
  
  # We apply the 5 dB safety margin from the heuristics to account for real-ear SPL variations:
  safe_mpo <- ldl_spl - 5
  
  # Final MPO: Take the heuristic MPO, but cap it at the Safe MPO limit.
  mpo <- pmin(heuristic_mpo, safe_mpo)
  
  # Absolute ceiling (Johnson 2017 PTS Safety Limits)
  # Limit output based on threshold to avoid permanent threshold shift.
  pts_safe_limit <- 105 + pmax(0, threshold - 50) * 0.5
  mpo <- pmin(mpo, pts_safe_limit)
  
  # ABSOLUTE CLINICAL HARD CAP: NEVER exceed 120 dB SPL
  mpo <- pmin(mpo, 120)
  
  return(mpo)
}
