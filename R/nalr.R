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

calculate_open_nl_gain <- function(freq, threshold, input_level, gender = "male", experience = "experienced", config = "bilateral", age = "adult", coupling = "custom_occluded") {
  # 1. Base Anchor (For 65 dB SPL input)
  # We use the NAL-R linear formula. NAL-R aggressively cuts low frequencies (-17 dB at 250 Hz). 
  # We just proved that if we flatten this (give more low-frequency gain), the SII DROPS due to 
  # upward spread of masking and level distortion. NAL-R's shape was optimal!
  g_65 <- pmax(0, calculate_nalr_gain(freq, threshold))
  
  # Add a Severe-Loss Booster: NAL-R (half-gain) under-amplifies severe losses.
  # For thresholds > 60 dB HL, we increase the gain ratio slightly.
  g_65 <- g_65 + pmax(0, threshold - 60) * 0.5
  
  # High-Frequency Desensitization Roll-off (Smooth Soft-Compression)
  # Instead of a harsh penalty or hard cap (which causes jagged artifacts),
  # we softly compress any insertion gain that exceeds 25 dB in the high frequencies.
  
  # Determine if there is a sloping component (difference between high and low thresholds)
  best_low_thresh <- min(threshold[freq <= 1000], na.rm = TRUE)
  slope_factor <- pmax(0, pmin(1, (threshold - best_low_thresh - 15) / 20))
  
  # Weighting factor that fades in from 1500 Hz to 3000 Hz
  hf_weight <- pmax(0, pmin(1, (freq - 1500) / 1500)) 
  
  # If the insertion gain tries to exceed 25 dB, we compress the excess (10:1 ratio)
  gain_limit <- 25
  excess_gain <- pmax(0, g_65 - gain_limit)
  compressed_excess <- excess_gain * 0.1 
  
  # Apply the smooth compression only to the high frequencies of a sloping loss
  g_65 <- g_65 - (hf_weight * slope_factor * (excess_gain - compressed_excess))
  
  # Ensure gain doesn't go below 0
  g_65 <- pmax(g_65, 0)
  
  # 2. Multi-channel WDRC Pivot
  # We pivot WDRC around the expected band level for normal speech (65 dB overall)
  data("critical", package="SII")
  pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
  
  # 3. Bi-directional Dynamic Range Optimization (WDRC)
  # To match evidence-based targets (e.g., Keidser et al., NAL-NL2), we scale the Compression Ratio (CR).
  
  # Mild (<40 HL): CR climbs from 1.0 to ~1.5
  # Moderate (40-65 HL): CR climbs from 1.5 to ~2.0
  base_cr <- 1 + pmax(0, threshold - 20) / 45
  
  # Severe/Profound (>65 HL): CR actually REDUCES back toward linear.
  # Patients with severe loss prefer lower compression (1:1 to 2:1) to preserve the temporal envelope.
  severe_penalty <- pmax(0, threshold - 65) / 30
  
  # Frequency dependence for severe loss:
  # Low frequencies (<1000 Hz) strongly prefer linear (CR ~1.0).
  # High frequencies can tolerate more compression (CR ~1.5 - 2.0).
  freq_modifier <- pmax(0, pmin(1, (freq - 500) / 2500)) # 0 at 500Hz, 1 at >=3000Hz
  adjusted_penalty <- severe_penalty * (1.5 - 0.5 * freq_modifier)
  
  cr_loud <- base_cr - adjusted_penalty
  
  # Clinical Limits: Ensure CR stays between 1.0 (linear) and a strict 2.5 maximum.
  cr_loud <- pmax(1.0, pmin(cr_loud, 2.5))
  
  # 3.5 Variable Compression Threshold (DSL v5.0a Philosophy)
  # Instead of a fixed low knee-point, the CT increases with hearing loss severity.
  ct_overall <- approx(x = c(20, 50, 80, 100), y = c(35, 45, 60, 70), xout = threshold, rule = 2)$y
  
  # ct_overall is the OVERALL speech level CT. We must convert it to a BAND level CT.
  # Since 'pivot' is the band level for 65 dB SPL overall speech, 
  # the band level CT is simply pivot + (ct_overall - 65).
  ct_band <- pivot + (ct_overall - 65)
  
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
