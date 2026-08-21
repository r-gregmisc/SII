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

get_recd_diff <- function(age, age_months = NULL) {
  recd_f <- c(250, 500, 1000, 2000, 4000, 8000)
  adult_recd <- c(2, 3, 5, 8, 10, 6)
  
  # If age is a string like "child_6_11", parse the months
  if (is.null(age_months) && !is.null(age) && substr(age[1], 1, 5) == "child") {
    if (age == "child_0_5") age_months <- 3
    else if (age == "child_6_11") age_months <- 9
    else if (age == "child_12_23") age_months <- 18
    else if (age == "child_24_35") age_months <- 30
    else if (age == "child_36_59") age_months <- 48
    else age_months <- 60
  }
  
  if (is.null(age) || age == "adult" || is.null(age_months)) {
    infant_recd <- adult_recd
  } else if (age_months <= 6) {
    infant_recd <- c(6, 8, 12, 15, 17, 14)
  } else if (age_months <= 12) {
    infant_recd <- c(5, 7, 10, 13, 15, 12)
  } else if (age_months <= 24) {
    infant_recd <- c(4, 6, 8, 11, 13, 10)
  } else {
    infant_recd <- c(3, 4, 6, 9, 11, 8)
  }
  
  return(list(f = recd_f, diff = infant_recd - adult_recd))
}

calculate_open_nl_gain <- function(freq, threshold, input_level, gender = "male", experience = "experienced", config = "bilateral", age = "adult", coupling = "custom_occluded", module = "standard", ldl = NULL, age_years = NULL, age_months = NULL, loss = NULL, distortion_category = NULL, user_cr = NULL) {
  # Define steep_slope_diff for HFDR and LDL logic
  steep_slope_diff <- if (length(threshold) > 1) max(diff(threshold), na.rm = TRUE) else 0

  # 0. Conductive Component Separation
  if (is.null(loss)) {
    loss <- rep(0, length(threshold))
  }
  sn_threshold <- pmax(0, threshold - loss)

  # 1. Base Anchor (For 65 dB SPL input)
  # NAL-style frequency-specific constants to shape the response
  c_freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
  
  if (experience == "new") {
    c_vals <- c(-3, 2, 3, 0, -2, -2, -2, -2)
  } else {
    c_vals <- c(-8, -1, 3, 1, 0, 0, 0, 0)
  }
  
  if (gender == "female") {
    c_vals <- c_vals - 1.5
  }
  c_interp <- approx(x = log10(c_freqs), y = c_vals, xout = log10(freq), rule = 2)$y

  # 2. Loudness-Density Normalization Heuristic (LDN-H)
  # Instead of arbitrary dynamic base multipliers, we anchor to the theoretically
  # derived 0.46 half-gain rule (Lyregaard, 1988; NAL-R).
  g_base <- 0.46 * sn_threshold + c_interp
  
  # A modest Severe-Loss Booster (0.15 slope) is applied to thresholds > 60 dB HL
  # to gently assist profound losses without triggering explosive recruitment.
  g_base <- g_base + 0.15 * pmax(0, sn_threshold - 60)
  
  # 3. Slope-Dependent Loudness Normalization
  # Because low frequencies dominate overall loudness, scaling severe losses
  # can cause loudness to explode if the loss is steeply sloping (i.e. normal lows, profound highs).
  # We calculate the low-frequency and high-frequency PTAs to determine the slope.
  pta_lf <- mean(sn_threshold[freq <= 1000], na.rm = TRUE)
  pta_hf <- mean(sn_threshold[freq >= 2000], na.rm = TRUE)
  if (is.na(pta_lf)) pta_lf <- 40
  if (is.na(pta_hf)) pta_hf <- 40
  
  slope_diff <- pta_hf - pta_lf
  
  if (slope_diff > 15 && pta_hf > 65) {
    # STEEP SLOPE: Aggressive penalty to low-frequency gain 
    # to prevent the overall loudness density from exceeding the comfort threshold (fixes A5 overprescription).
    lf_penalty_factor <- pmin(1, (slope_diff - 15) / 20)
    lf_penalty_max <- lf_penalty_factor * 15 # Up to 15 dB penalty
    
    lf_weights <- pmax(0, 1 - (log10(freq) - log10(250)) / log10(1000/250))
    g_base <- g_base - (lf_penalty_max * lf_weights)
  } else if (slope_diff < -15) {
    # REVERSE SLOPE: Low frequencies are significantly worse than high frequencies.
    # We must suppress low-frequency gain to prevent upward spread of masking.
    rs_factor <- pmin(1, (-slope_diff - 15) / 20)
    flat_target <- -10
    lf_weights <- pmax(0, 1 - (log10(freq) - log10(250)) / log10(1000/250))
    # Apply the -10 dB suppression to the correction array (c_interp) in the low frequencies
    # rather than flattening the entire g_base to -10 (which would cause severe attenuation)
    g_base <- g_base - (c_interp - flat_target) * rs_factor * lf_weights
  }
  # For FLAT audiograms (slope_diff between -15 and 15), NO low-frequency penalty is applied.
  # This solves the A4 under-prescription paradox by allowing severe flat losses to retain their 50% gain.
  
  g_65 <- g_base
  
  # High-Frequency Desensitization Roll-off (Smooth Soft-Compression)
  # Instead of a harsh penalty or hard cap (which causes jagged artifacts),
  # we softly compress any insertion gain that exceeds 25 dB in the high frequencies.
  
  # Determine if there is a sloping component (difference between high and low thresholds)
  best_low_thresh <- min(sn_threshold[freq <= 1000], na.rm = TRUE)
  # The slope factor measures how far above the best low threshold a particular frequency is
  # It scales from 0 (if within 25 dB) up to 1 (if > 45 dB worse than low frequencies).
  slope_factor <- pmax(0, pmin(1, (sn_threshold - best_low_thresh - 25) / 20))
  
  # Weighting factor that fades in from 2000 Hz to 4000 Hz
  hf_weight <- pmax(0, pmin(1, (freq - 2000) / 2000)) 
  
  # We dynamically scale the gain limit so severe losses can still get the amplification they need.
  # Lifted base limit to 45 dB, and increased the slope multiplier to 1.0 
  # to prevent severe/profound losses from being crushed by soft-compression (Macrae, 1991).
  if (!is.null(age) && substr(age[1], 1, 5) == "child") {
    gain_limit <- 45 + pmax(0, sn_threshold - 60) * 1.0
  } else if (experience == "power") {
    gain_limit <- 45 + pmax(0, sn_threshold - 60) * 1.0
  } else {
    gain_limit <- 45 + pmax(0, sn_threshold - 60) * 1.0
  }
  
  if (!is.null(distortion_category) && distortion_category %in% c("Moderate", "High") && (is.null(age) || substr(age[1], 1, 5) != "child")) {
    gain_limit <- gain_limit - 10 # Increase soft compression significantly for distorted ears
  }
  
  excess_gain <- pmax(0, g_65 - gain_limit)
  
  # Compress the excess (2:1 ratio instead of 4:1 to allow more gain through)
  compressed_excess <- excess_gain * 0.50 
  
  # Apply the smooth compression only to the high frequencies of a sloping loss
  g_65 <- g_65 - (hf_weight * slope_factor * (excess_gain - compressed_excess))
  
  # 1.5 Dynamic Range Mapping (DSL v5.0 philosophy)
  # Compare measured LDL to expected LDL (adding loss to properly account for conductive component)
  predicted_ldl_spl <- 100 + pmax(0, sn_threshold - 40) * 0.5 + loss
  
  if (!is.null(ldl) && length(ldl) == length(sn_threshold)) {
    measured_ldl_spl <- ifelse(is.na(ldl), predicted_ldl_spl, ldl + 10)
    ldl_diff <- measured_ldl_spl - predicted_ldl_spl
  } else {
    ldl_diff <- 0
  }
  
  # Decrease gain if LDL is lower than expected (dynamic range is squeezed)
  # 0.2 dB gain reduction for every 1 dB the LDL is lowered
  g_65 <- g_65 + (ldl_diff * 0.2)
  
  # 1e. NAL-NL3 Bandwidth Roll-off
  # Reduced emphasis on using low-frequency (<= 250 Hz) and very high-frequency (>= 6 kHz) gain
  if (!is.null(age) && substr(age[1], 1, 5) == "child") {
    bw_rolloff <- approx(x = c(250, 500, 1000, 2000, 4000, 6000, 8000), 
                         y = c(0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0), xout = freq, rule = 2)$y
  } else {
    bw_rolloff <- approx(x = c(250, 500, 1000, 2000, 4000, 6000, 8000), 
                         y = c(0.7, 1.0, 1.0, 1.0, 1.0, 0.8, 0.5), xout = freq, rule = 2)$y
  }
  g_65 <- g_65 * bw_rolloff
  
  
  # 1d. Margolis et al. (2025) Distortion Categorization Roll-off
  # Based on the untested heuristic in Appendix A.
  if (!is.null(distortion_category) && (is.null(age) || substr(age[1], 1, 5) != "child")) {
    if (distortion_category == "Moderate") {
      # Roll off -5 dB per octave above 2000 Hz
      dist_roll <- pmax(0, log2(freq / 2000)) * 5
      g_65 <- g_65 - dist_roll
    } else if (distortion_category == "High") {
      # Roll off -10 dB per octave above 1500 Hz
      dist_roll <- pmax(0, log2(freq / 1500)) * 10
      g_65 <- g_65 - dist_roll
    }
  }
  
  # 2. Multi-channel WDRC Pivot
  # We pivot WDRC around the expected band level for normal speech (65 dB overall)
  if (file.exists(file.path("data", "critical.rda"))) {
    load(file.path("data", "critical.rda"), envir = environment())
  } else {
    data("critical", package="SII", envir = environment())
  }
  pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
  

  # 3. Bi-directional Dynamic Range Optimization (WDRC)
  # To match evidence-based targets (e.g., Keidser et al., NAL-NL2), we scale the Compression Ratio (CR).
  
  # Moderate (40-65 HL):
  # To preserve the speech envelope and avoid SNR degradation at high levels (Hornsby & Ricketts, 2001),
  # we scale the CR conservatively.
  base_cr <- 1 + pmax(0, sn_threshold - 20) / 40
  
  # Adjust base_cr based on LDL discrepancy
  # A lower LDL (squeezed dynamic range) requires a higher compression ratio
  base_cr <- base_cr - (ldl_diff * 0.02)
  
  freq_modifier <- pmax(0, pmin(1, (freq - 500) / 2500)) # 0 at 500Hz, 1 at >=3000Hz
  max_cr <- 1.5 + (0.9 * freq_modifier) # 1.5 at <=500Hz, 2.4 at >=3000Hz
  
  if (!is.null(user_cr) && length(user_cr) == length(freq)) {
    cr_loud <- user_cr
  } else {
    cr_loud <- base_cr
  }
  
  cr_loud <- pmax(1.0, pmin(cr_loud, max_cr))
  
  # 3.5 Variable Compression Threshold (CT)
  # Standardizing CT to be universally lower (30-45 dB SPL) to match NAL-NL2 and DSL.
  # A lower CT ensures WDRC kicks in earlier, applying more gain to soft speech (55 dB SPL).
  # This restores audibility for soft sounds and dramatically reduces listening effort,
  # especially when using our lower-gain comfort multipliers (e.g. 0.40 / 0.45).
  if (!is.null(age) && substr(age[1], 1, 5) == "child") {
    ct_overall <- approx(x = c(20, 50, 80, 100), y = c(25, 30, 35, 40), xout = sn_threshold, rule = 2)$y
  } else if (experience == "power") {
    ct_overall <- approx(x = c(20, 50, 80, 100), y = c(25, 30, 35, 40), xout = sn_threshold, rule = 2)$y
  } else {
    ct_overall <- approx(x = c(20, 50, 80, 100), y = c(30, 35, 40, 45), xout = sn_threshold, rule = 2)$y
  }
  
  # ct_overall is the OVERALL speech level CT. We must convert it to a BAND level CT.
  # Since 'pivot' is the band level for 65 dB SPL overall speech, 
  # the band level CT is simply pivot + (ct_overall - 65).
  ct_band <- pivot + (ct_overall - 65)
  
  # 3.7 Aggressive MPO Defense (Collision Prevention)
  # For steeply sloping losses with low LDLs, loud speech peaks run a high risk of 
  # striking the MPO limit, causing severe distortion. We aggressively lower the CT 
  # and increase the CR to squash the peaks.
  if (!is.null(ldl) && length(ldl) == length(sn_threshold)) {
    measured_ldl_spl <- ifelse(is.na(ldl), predicted_ldl_spl, ldl + 10)
    low_ldl_mask <- measured_ldl_spl < 100
    
    if (steep_slope_diff > 15 && any(low_ldl_mask)) {
      ldl_penalty <- pmax(0, 100 - measured_ldl_spl)
      
      # Drop CT by up to 10 dB, engaging compression earlier
      ct_band <- ct_band - ldl_penalty
      
      # Forcefully increase the CR in the danger zones
      cr_loud[low_ldl_mask] <- cr_loud[low_ldl_mask] + (ldl_penalty[low_ldl_mask] * 0.05)
    }
  }
  
  # 3.8 Comfort in Noise (CIN) Module
  if (module == "cin") {
    # Comfort in Noise (CIN) module aims to reduce loudness and improve comfort
    # 3. Apply Multi-Stage WDRC limits
  # Higher thresholds require lower compression ratios to preserve the speech envelope
  # in high-level noise environments. (Keidser et al., 2012).
  cr_loud <- 1 + (sn_threshold / 50)
  cr_loud <- pmin(cr_loud, 2.0)
  
  # For severe losses (>70 dB HL), we drop the CR back down to preserve modulation depth.
  cr_loud <- ifelse(sn_threshold > 70, 1.5, cr_loud)
    
    # We lower the WDRC pivot / CT so compression kicks in earlier.
    ct_band <- ct_band - 10
  }
  
  # The target gain 'g_65' is prescribed for an input level of 'pivot' (the band level for 65 dB overall).
  # We convert the overall input_level to the corresponding band level:
  input_band <- pivot + (input_level - 65)
  
  # If CT > pivot, the pivot is in the linear region, so the linear gain is simply g_65.
  # If CT <= pivot, the pivot is in the WDRC region. We calculate the gain at CT by climbing the WDRC slope backward.
  g_ct <- ifelse(ct_band > pivot,
                 g_65, 
                 g_65 + (pivot - ct_band) * (1 - 1/cr_loud))
  
  # 4. Multistage I/O calculation (Linear below CT, WDRC above CT)
  ig <- ifelse(input_band <= ct_band,
               g_ct,
               g_ct - (input_band - ct_band) * (1 - 1/cr_loud))
               
  # 5. Apply Infant/Toddler RECD Correction
  # Infants have smaller ear canals, meaning the same hearing aid output produces a higher SPL at the eardrum.
  # To achieve the same target SPL at the eardrum, the prescribed insertion gain must be reduced 
  # by the difference between the infant RECD and the adult RECD.
  recd_data <- get_recd_diff(age, age_months)
  recd_diff <- approx(x = log10(recd_data$f), y = recd_data$diff, xout = log10(freq), rule = 2)$y
  
  ig <- ig - recd_diff
  
  # 6. Apply Empirical Demographic Adjustments (Keidser et al., 2012)
  adjustment <- 0
  
  # Gender: Females prefer ~1.5 dB less gain
  if (gender == "female") {
    adjustment <- adjustment - 1.5
  }
  # Age / Acquired-Loss Penalty (DSL v5.0a Philosophy)
  # Adults prefer less gain than children, particularly for mild-to-moderate losses.
  # This difference shrinks as the hearing loss becomes more severe.
  if (!is.null(age) && substr(age[1], 1, 5) == "child") {
    # We apply a dynamic boost for children relative to the adult baseline.
    # ~5 dB for mild/moderate losses, tapering to ~1 dB for severe losses.
    child_boost <- approx(x = c(20, 50, 80, 100), y = c(5, 5, 2, 1), xout = sn_threshold, rule = 2)$y
    adjustment <- adjustment + child_boost
  }
  # Configuration: Unilateral fittings require ~3 dB more gain due to lack of binaural summation
  if (config == "unilateral") {
    adjustment <- adjustment + 3.0
  }
  
  # Experience: New users with PTA > 40 prefer less gain (up to 6 dB less)
  if (experience == "new") {
    pta_val <- mean(sn_threshold[freq %in% c(500, 1000, 2000)], na.rm = TRUE)
    if (!is.na(pta_val) && pta_val > 40) {
      exp_penalty <- (pta_val - 40) * 0.3
      exp_penalty <- pmin(exp_penalty, 6.0)
      adjustment <- adjustment - exp_penalty
    }
  }
  
  ig <- ig + adjustment
  
  # 7. Apply Acoustic Coupling / Vent Effect (Caporali et al., 2019)
  # Simulated Real-Ear Aided Response (REAR) by subtracting leakage.
  if (coupling != "custom_occluded") {
    ve_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
    if (coupling == "open_dome") {
      ve_loss <- c(-35, -28, -15, -2, 0, 0)
    } else if (coupling == "tulip_dome") {
      ve_loss <- c(-25, -18, -5, 0, 0, 0)
    } else if (coupling == "double_dome") {
      ve_loss <- c(-20, -10, 0, 0, 0, 0)
    } else if (coupling == "vent_1mm_solid") {
      ve_loss <- c(-3, -1, 0, 0, 0, 0)
    } else if (coupling == "vent_2mm_solid") {
      ve_loss <- c(-8, -2, 0, 0, 0, 0)
    } else if (coupling == "vent_3mm_solid") {
      ve_loss <- c(-12, -4, 0, 0, 0, 0)
    } else if (coupling == "vent_1mm_hollow") {
      ve_loss <- c(-12, -3, 0, 0, 0, 0)
    } else if (coupling == "vent_2mm_hollow") {
      ve_loss <- c(-22, -12, -5, -2, 0, 0)
    } else if (coupling == "vent_3mm_hollow") {
      ve_loss <- c(-25, -15, -8, -4, 0, 0)
    } else {
      ve_loss <- c(0, 0, 0, 0, 0, 0)
    }
    
    ve_interp <- approx(x = log10(ve_freqs), y = ve_loss, xout = log10(freq), rule = 2)$y
    ig <- ig + ve_interp
  } else {
    ve_interp <- rep(0, length(freq))
  }
  
  # 8. Conductive Component Correction
  # Restore 75% of the Air-Bone Gap as linear gain, as specified by NAL-NL2 / Johnson (2013).
  # Cap at 30 dB to prevent runaway loudness in extreme ABG cases (Ching et al., 2013).
  abg_gain <- pmin(0.75 * loss, 30)
  
  # Apply a gentle 6 dB low-frequency taper to the ABG gain (fading out by 1000 Hz)
  # to prevent upward spread of masking without being overkill or destroying the smooth response.
  abg_lf_penalty <- ifelse(freq < 1000, 6 * (log10(1000) - log10(freq)) / log10(1000/250), 0)
  abg_gain <- pmax(0, abg_gain - abg_lf_penalty)
  ig <- ig + abg_gain
  
  # Ensure the target insertion gain doesn't demand impossible active noise cancellation.
  # We floor the target at slightly below the physical insertion loss of the vent/coupling.
  # A hard floor at 0 dB forces the hearing aid to fight open vents, causing massive comb filtering.
  ig <- pmax(ig, ve_interp - 10, na.rm = TRUE)
  
  # Absolute ceiling: Insertion gain should not exceed 85% of the total threshold to prevent permanent threshold shift (PTS).
  ig <- pmin(ig, 0.85 * threshold, na.rm = TRUE)
  
  # 9. MPO-domain saturation limit
  # The output of the hearing aid must not exceed the predicted LDL.
  # Instead of hard-clipping the WDRC gain (which starves soft sounds),
  # we cap the gain such that the final aided output never exceeds the LDL minus a 5 dB buffer.
  mpo_spl_ceiling <- predicted_ldl_spl - 5
  
  # The absolute maximum gain is the ceiling minus the current input level (band level).
  # This correctly allows large gain for soft sounds while compressing loud sounds.
  max_allowable_ig <- mpo_spl_ceiling - input_band
  ig <- pmin(ig, max_allowable_ig, na.rm = TRUE)

  
  return(ig)
}

calculate_nal_sspl90 <- function(threshold, gain, ldl = NULL, age = "adult", age_months = NULL, loss = NULL, freq = c(250, 500, 1000, 2000, 4000, 8000)) {
  # 0. Separate Sensorineural component
  if (is.null(loss)) {
    loss <- rep(0, length(threshold))
  }
  sn_threshold <- pmax(0, threshold - loss)

  # NAL SSPL90 rule (Maximum Power Output)
  # Derived from Dillon (2012) and NAL guidelines for avoiding discomfort
  
  # 1. Base SSPL90 for normal hearing is roughly 90-100 dB SPL (we use 105 to provide headroom)
  # 2. SSPL90 increases by roughly 0.5 dB for every 1 dB of sensorineural hearing loss above 20 dB HL
  # 3. Add conductive loss linearly since it attenuates the entire signal reaching the cochlea.
  heuristic_mpo <- 105 + pmax(0, sn_threshold - 20) * 0.5 + loss
  
  # 3. Estimated LDL & Safety Margin
  # Estimated LDLs often range around 100 dB SPL for normal hearing, 
  # expanding up to 130-140 dB SPL for profound loss. 
  estimated_ldl_spl <- 105 + pmax(0, sn_threshold - 20) * 0.5 + loss
  
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
  if (!is.null(age) && substr(age[1], 1, 5) == "child") {
    pts_safe_limit <- 110 + pmax(0, sn_threshold - 50) * 0.5 + loss
  } else {
    pts_safe_limit <- 105 + pmax(0, sn_threshold - 50) * 0.5 + loss
  }
  mpo <- pmin(mpo, pts_safe_limit)
  
  # ABSOLUTE CLINICAL HARD CAP: 
  # We removed the arbitrary 120 dB SPL max_cochlear cap for adults. 
  # Macrae (1991) and Johnson (2017) demonstrated that profoundly damaged cochleas 
  # safely tolerate (and require) up to 130-135 dB SPL to achieve speech audibility.
  # Infants still require careful monitoring of RECD limits.
  recd_data <- get_recd_diff(age, age_months)
  recd_diff <- approx(x = log10(recd_data$f), y = recd_data$diff, xout = log10(freq), rule = 2)$y
  
  if (!is.null(age) && substr(age[1], 1, 5) == "child") {
    max_cochlear <- 125 + loss - recd_diff
    mpo <- pmin(mpo, max_cochlear)
  }
  
  # ABSOLUTE HARDWARE LIMIT: Acoustic hearing aids max out around 135 dB SPL.
  mpo <- pmin(mpo, 135)
  
  return(mpo)
}

#' Prescribe Compression Settings based on Hearing Loss
#'
#' @description
#' Provides recommendations for compression speed (fast vs slow acting) and
#' compression ratio/release times based on the four-frequency Pure Tone Average (PTA4).
#'
#' @param freq A numeric vector of frequencies.
#' @param threshold A numeric vector of hearing thresholds.
#' @param module The operating module ("standard", "cin").
#' @return A list containing compression recommendations.
#' @export
prescribe_compression <- function(freq, threshold, module = "standard") {
  # Calculate 4-frequency Pure Tone Average (PTA4)
  pta_freqs <- c(500, 1000, 2000, 4000)
  if (all(pta_freqs %in% freq)) {
    pta_thresh <- threshold[match(pta_freqs, freq)]
  } else {
    pta_thresh <- approx(x = log10(freq), y = threshold, xout = log10(pta_freqs), rule = 2)$y
  }
  pta4 <- mean(pta_thresh, na.rm = TRUE)
  
  if (pta4 >= 35) {
    speed <- "Slow-acting"
    release_time <- "> 500 ms"
    speed_reason <- sprintf("PTA4 \u2265 35 dB HL (%.1f dB HL)", pta4)
  } else {
    speed <- "Fast-acting"
    release_time <- "< 200 ms"
    speed_reason <- sprintf("PTA4 < 35 dB HL (%.1f dB HL)", pta4)
  }
  
  ratio_note <- "Target \u2264 2:1. If CR \u2265 3:1 is necessary, use longer release time (e.g., 1000 ms) to preserve clarity."
  if (module == "cin") {
    ratio_note <- "Comfort in Noise (CIN): Prescribing lower compression (linear to 1.5:1) for high-level noise."
  }
  
  return(list(
    pta4 = pta4,
    speed = speed,
    release_time = release_time,
    speed_reason = speed_reason,
    ratio_note = ratio_note
  ))
}
