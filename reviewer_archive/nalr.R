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

calculate_open_nl_gain <- function(freq, threshold, input_level, gender = "male", experience = "experienced", config = "bilateral", age = "adult", coupling = "custom_occluded", module = "standard", ldl = NULL, age_years = NULL, age_months = NULL, loss = NULL, distortion_category = NULL, f_e_hf = NULL, f_e_lf = NULL, abg_fraction = 0.75, ...) {
  # Defensive guard: ensure module is always a valid length-1 string
  if (is.null(module) || length(module) == 0 || !nzchar(module)) module <- "standard"
  
  # 0. Conductive Component Separation
  if (is.null(loss)) {
    loss <- rep(0, length(threshold))
  }
  sn_threshold <- pmax(0, threshold - loss)


  # 0. Minimal Hearing Loss (MHL) Module Bypass
  # If the patient has near-normal hearing (PTA <= 25) and selects the MHL module,
  # we completely bypass the standard WDRC compensation formula.
  pta_4 <- mean(sn_threshold[freq %in% c(500, 1000, 2000, 4000)], na.rm = TRUE)
  if (module == "mhl" && !is.na(pta_4) && pta_4 <= 25) {
    # MHL applies a flat 3-5 dB insertion gain above 1kHz to access SNR features,
    # tapering strictly to 0 dB in the low frequencies.
    mhl_gain <- approx(x = c(250, 500, 1000, 2000, 4000, 8000), 
                       y = c(0, 0, 3, 5, 5, 5), xout = freq, rule = 2)$y
                       
    # Linear amplification for speech inputs up to 65 dB SPL
    data("critical", envir = environment())
    pivot <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
    ct_band <- pivot + 5 # Set CT slightly above normal speech
    
    g_ct <- mhl_gain
    cr_loud <- 1.5 # Gentle compression for loud inputs to prevent discomfort
    
    band_input <- pivot + (input_level - 65)
    ig <- ifelse(band_input <= ct_band,
                 g_ct,
                 g_ct - (band_input - ct_band) * (1 - 1/cr_loud))
                 

    
    return(ig)
  }
  
  # 1. Base Anchor (For 65 dB SPL input)
  # We use a frequency-specific half-gain anchor decoupled from broadband PTA, similar to NAL-NL2 and DSL.
  # This prevents normal low-frequency hearing from artificially dragging down high-frequency gain.
  c_freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
  
  # Base WDRC Anchor according to manuscript
  base_mult <- 0.46
  
  # Standard experienced user baseline (from manuscript)
  c_vals <- c(-8, -1, 3, 1, 0, 0, 0, 0)
  
  if (experience == "new") {
    # New Users receive a purely nominal, uncalibrated flat -3 dB reduction
    c_vals <- c_vals - 3
  } else if (experience == "power") {
    # Power Users (not defined in manuscript, but present in UI) get +3 dB
    c_vals <- c_vals + 3
  }
  
  c_interp <- approx(x = log10(c_freqs), y = c_vals, xout = log10(freq), rule = 2)$y
  # 1a. Reverse Slope Correction
  # For reverse slope losses (where low frequencies are significantly worse than high frequencies),
  # attempting to fully restore low/mid-frequency audibility causes severe upward spread of masking,
  # where low-frequency amplification (e.g. vowels, ambient noise) masks the normal high-frequency consonants.
  # We must apply an additional penalty in the 400-1500 Hz range to prevent this.
  low_thresh_mean <- mean(sn_threshold[freq <= 1000], na.rm = TRUE)
  high_thresh_mean <- mean(sn_threshold[freq >= 2000], na.rm = TRUE)
  
  # Eq. 6: Slope_signed (negative means reverse slope)
  slope_signed <- high_thresh_mean - low_thresh_mean
  
  if (slope_signed < -15) {
    rs_factor <- pmin(1, (-slope_signed - 15) / 20)
    
    # Log-linear taper applied to frequencies below 1000 Hz
    w_lf <- pmax(0, pmin(1, 1 - (log10(freq) - log10(250)) / log10(1000/250))) 
    
    # Eq. 7: Apply the -10 dB floor ONLY to the low frequencies via W_LF taper
    c_interp <- c_interp * (1 - rs_factor * w_lf) + (-10 * rs_factor * w_lf)
  }
  
  # Base multiplier is 0.46 (from manuscript, defined above)
  
  # Slope Penalty: If there is a massive difference between high and low thresholds,
  # standard half-gain will cause too much gain in the low frequencies (upward spread of masking)
  # and heavily penalize gain there to prevent the low/mid frequencies from masking the highs.
  # We also boost the high frequencies to pull them out of the slope.
  steep_slope_diff <- pmax(0, high_thresh_mean - low_thresh_mean)
  
  # 1c. Explicit Dead Region Edge Frequencies
  # We no longer automatically infer dead regions from thresholds alone, as this is clinically invalid.
  # Defaults to Inf / -Inf if not explicitly provided, bypassing the dead region roll-offs.
  f_e_hf <- if (!is.null(f_e_hf)) f_e_hf else Inf
  f_e_lf <- if (!is.null(f_e_lf)) f_e_lf else -Inf
  
  if (steep_slope_diff > 15) {
    # Profound High-Frequency Bypass (PF_bypass) - Eq. 3
    # If high frequencies are extremely severe (>70 dB HL), we bypass the low frequency penalty 
    # so they can still hear low frequency cues.
    pf_bypass <- pmax(0, pmin(1, (95 - high_thresh_mean) / 25))
    
    # Scale the penalty over a 20 dB window, cap at 15 dB (Eq. 4)
    steep_factor <- pmin(1, (steep_slope_diff - 15) / 20)
    lf_penalty <- steep_factor * 15 * pf_bypass
    
    # Log-linear taper applied to frequencies below 1000 Hz
    lf_weight <- pmax(0, pmin(1, 1 - (log10(freq) - log10(250)) / log10(1000/250))) 
    
    c_interp <- c_interp - (lf_penalty * lf_weight)
  }

  
  # Use the dynamically selected base multiplier based on user experience.
  # This globally sets the 65 dB SPL anchor to match user comfort vs audibility needs.
  # We DO NOT bound this to 0 here because normal hearing needs negative insertion gain to shape the response!
  g_65 <- base_mult * sn_threshold + c_interp
  
  # Severe-Loss Booster (Section II.F)
  # Bounded severe-loss booster (slope = 0.15) applied to thresholds.
  # The manuscript defaults to off, but Eq. 1 uses the 60 dB HL aggressive onset.
  # We apply the 0.15 slope and remove the undocumented tapers (dead region & mid-taper).
  b_en <- 1.0 # Set to 1.0 to enable the aggressive ablation mode from Eq. 1
  slb_final <- b_en * 0.15 * pmax(0, pmin(80, sn_threshold) - 60)
  
  g_65 <- g_65 + slb_final
  
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
  # Lifted base limit from 25 to 30 dB to prevent underamplification of steep slopes
  if (experience == "power") {
    gain_limit <- 40 + pmax(0, sn_threshold - 60) * 0.5
  } else {
    gain_limit <- 30 + pmax(0, sn_threshold - 60) * 0.4
  }
  
  if (!is.null(distortion_category) && distortion_category %in% c("Moderate", "High")) {
    gain_limit <- gain_limit - 10 # Increase soft compression significantly for distorted ears
  }
  
  excess_gain <- pmax(0, g_65 - gain_limit)
  
  # Compress the excess (2:1 ratio instead of 4:1 to allow more gain through)
  compressed_excess <- excess_gain * 0.50 
  
  # Apply the smooth compression only to the high frequencies of a sloping loss
  g_65 <- g_65 - (hf_weight * slope_factor * (excess_gain - compressed_excess))
  
  # 1.5 Dynamic Range Mapping (DSL v5.0 philosophy)
  # Compare measured LDL to expected LDL
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
  bw_rolloff <- approx(x = c(250, 500, 1000, 2000, 4000, 6000, 8000), 
                       y = c(0.7, 1.0, 1.0, 1.0, 1.0, 0.8, 0.5), xout = freq, rule = 2)$y
  g_65 <- g_65 * bw_rolloff
  
  
  # 1d. Cochlear Dead Region Roll-off
  # Based on Moore (2001, 2004) and Vickers et al. (2001).
  # If a dead region is detected, amplifying beyond its viable boundary provides no speech 
  # intelligibility benefit and causes distortion/feedback.
  
  # Margolis et al. (2025) Distortion Categorization Roll-off
  if (!is.null(distortion_category)) {
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
  
  # High-Frequency Dead Region (HFDR)
  if (is.finite(f_e_hf)) {
    if (steep_slope_diff > 30) {
      # If the slope is steep, start the roll-off slightly before the dead region boundary (0.85x) 
      # and apply a technically feasible acoustic roll-off (30 dB/oct) to prevent severe phase distortion.
      hf_cutoff <- 0.85 * f_e_hf
      hf_dr_penalty <- pmax(0, log2(freq / hf_cutoff)) * 30 # Graceful, physically achievable roll-off
    } else {
      # Otherwise, we use Moore's 1.7x basal spread allowance.
      hf_cutoff <- 1.7 * f_e_hf
      hf_dr_penalty <- pmax(0, log2(freq / hf_cutoff)) * 30
    }
    
    g_65 <- g_65 - hf_dr_penalty
  }
  
  # Low-Frequency Dead Region (LFDR)
  if (is.finite(f_e_lf)) {
    lf_cutoff <- 0.57 * f_e_lf
    
    # Apply a steep penalty of 30 dB per octave below the cutoff
    lf_dr_penalty <- pmax(0, log2(lf_cutoff / freq)) * 30
    g_65 <- g_65 - lf_dr_penalty
  }
  
  # 2. Multi-channel WDRC Pivot
  # We pivot WDRC around the expected band level for normal speech (65 dB overall)
  data("critical", envir = environment())
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
  
  # Severe/Profound (>65 HL): CR actually REDUCES back toward linear.
  # Patients with severe loss prefer lower compression (1:1 to 2:1) to preserve the temporal envelope.
  severe_penalty <- pmax(0, sn_threshold - 65) / 30
  
  # Frequency dependence for severe loss:
  # Low frequencies (<1000 Hz) strongly prefer linear (CR ~1.0).
  # High frequencies can tolerate more compression (CR ~1.5 - 2.0).
  freq_modifier <- pmax(0, pmin(1, (freq - 500) / 2500)) # 0 at 500Hz, 1 at >=3000Hz
  adjusted_penalty <- severe_penalty * (1.5 - 0.5 * freq_modifier)
  
  cr_loud <- base_cr - adjusted_penalty
  
  # Clinical Limits: Ensure CR stays between 1.0 (linear) and a strict frequency-dependent maximum.
  # Based on Keidser et al. (2007) and Hornsby & Ricketts (2001), low frequencies are strictly capped at 1.5,
  # while high frequencies can tolerate slightly more (up to 2.4).
  max_cr <- 1.5 + (0.9 * freq_modifier) # 1.5 at <=500Hz, 2.4 at >=3000Hz
  
  # Grant & Walden (2013) Age-based Compression Relaxing
  # Older adults (>60 years) have significantly poorer temporal resolution (gap detection).
  # We reduce the max_cr progressively toward 1.5 to preserve the temporal speech envelope.
  if (!is.null(age_years) && age == "adult" && age_years > 60) {
    age_factor <- pmin(1.0, (age_years - 60) / 30.0) # Scales from 0 at age 60 to 1 at age 90
    max_cr <- max_cr - (max_cr - 1.5) * age_factor
  }
  
  cr_loud <- pmax(1.0, pmin(cr_loud, max_cr))
  
  # 3.5 Variable Compression Threshold (CT)
  # Standardizing CT to be universally lower (30-45 dB SPL) to match NAL-NL2 and DSL.
  # A lower CT ensures WDRC kicks in earlier, applying more gain to soft speech (55 dB SPL).
  # This restores audibility for soft sounds and dramatically reduces listening effort,
  # especially when using our lower-gain comfort multipliers (e.g. 0.40 / 0.45).
  if (experience == "power") {
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
    # in high-level noise environments. Based on evidence, listeners prefer
    # less compression (linear or 1.5:1) when noise exceeds the compression threshold.
    cr_loud <- pmin(cr_loud, 1.5)
    
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
  # input_level is the OVERALL speech level (e.g. 50, 65, 80). 
  # We must convert it to the BAND level by referencing the pivot (which is the band level at 65 dB overall).
  band_input <- pivot + (input_level - 65)
  
  ig <- ifelse(band_input <= ct_band,
               g_ct,
               g_ct - (band_input - ct_band) * (1 - 1/cr_loud))
               

  
  # 6. Apply Empirical Demographic Adjustments (Keidser et al., 2012)
  adjustment <- 0
  
  # Gender: Females prefer ~1.5 dB less gain
  if (gender == "female") {
    adjustment <- adjustment - 1.5
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
  # Restore the Air-Bone Gap as linear gain. Since conductive loss acts as a 
  # pre-cochlear attenuator (earplug), upward spread of masking does not apply,
  # and we can fully restore the loss without penalty (abg_fraction = 1.0).
  abg_gain <- abg_fraction * loss
  
  ig <- ig + abg_gain
  
  # Ensure the target insertion gain doesn't demand impossible active noise cancellation.
  # We floor the target at slightly below the physical insertion loss of the vent/coupling.
  # A hard floor at 0 dB forces the hearing aid to fight open vents, causing massive comb filtering.
  ig <- pmax(ig, ve_interp - 10, na.rm = TRUE)
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
  pts_safe_limit <- 105 + pmax(0, sn_threshold - 50) * 0.5 + loss
  mpo <- pmin(mpo, pts_safe_limit)
  
  # ABSOLUTE CLINICAL HARD CAP: NEVER exceed 120 dB SPL (at the cochlea)
  max_cochlear <- 120 + loss
  mpo <- pmin(mpo, max_cochlear)
  
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
#' @param module The operating module ("standard", "cin", "mhl").
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
