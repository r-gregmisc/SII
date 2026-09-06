#' Open-NL WDRC Gain Prescription
#'
#' @description
#' Calculates experimental prescriptive insertion gain and SSPL90 targets for a given hearing loss, based on a rule-based WDRC heuristic.
#' 
#' @details
#' This experimental function generates non-linear prescriptive targets for research and modeling purposes. It is not intended for clinical use.
#' 
#' @author
#' Mark Shaver
#'
#' @param speech Input speech spectrum level at each frequency. If a single number is provided, it's assumed to be the overall broadband SPL.
#' @param threshold Hearing threshold level at each frequency.
#' @param freq Frequencies at which the thresholds are measured.
#' @param gender Gender of the patient ("male", "female").
#' @param experience Hearing aid experience ("new", "experienced").
#' @param config Fitting configuration ("unilateral", "bilateral").
#' @param coupling Acoustic coupling ("custom_occluded", "open_dome", "tulip_dome", "double_dome", "vent_1mm_solid", etc.).
#' @param module Fitting module ("standard", "cin").
#' @param ldl Loudness Discomfort Levels (optional).
#' @param loss Conductive hearing loss component (optional).
#' @param distortion_category Distortion category ("Normal", "Low", "Moderate", "High").

#' @param user_cr User defined compression ratio (optional).
#' @param optimize Optimization flag.
#' @param seed_noise Random noise for optimizer seeding.
#' @param optim_method Optimization method.
#' @param abg_fraction Air-bone gap fraction to compensate.
#' @param enable_severe_booster Logical flag to enable severe-loss booster.
#' @param booster_onset Threshold for the severe-loss booster (default: 70).
#' @param disable_sdlfp Logical flag to disable the Slope-Dependent Low-Frequency Penalty (SD-LFP).
#' @param ... Additional graphical or printing parameters.
#'
#' @return An object of class \code{prescription_target}.
#' @importFrom stats var
#' @export
open_nl <- function(speech = 65, threshold, freq, ..., 
                    gender = "male", experience = "experienced", 
                    config = "bilateral", 
                    coupling = "custom_occluded", module = "standard", 
                    ldl = NULL, 
                    loss = NULL, distortion_category = NULL, 
                    user_cr = NULL,
                    optimize = TRUE, seed_noise = NULL, optim_method = "Nelder-Mead",
                    abg_fraction = 0.75, enable_severe_booster = FALSE, booster_onset = 70, disable_sdlfp = FALSE) {
  
  if (length(speech) == 1) {
    if (file.exists(file.path("data", "critical.rda"))) {
      load(file.path("data", "critical.rda"), envir = environment())
    } else {
      data("critical", package="SII", envir = environment())
    }
    # Interpolate critical band speech to requested frequencies
    normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
    overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
    speech_spec <- normal_speech + (speech - overall_normal)
    overall_level <- speech
  } else {
    speech_spec <- speech
    overall_level <- 65 # Fallback
  }
  
  gain <- calculate_open_nl_gain(freq=freq, threshold=threshold, input_level=overall_level, gender=gender, experience=experience, config=config, coupling=coupling, module=module, ldl=ldl, loss=loss, distortion_category=distortion_category, user_cr=user_cr, abg_fraction=abg_fraction, enable_severe_booster=enable_severe_booster, booster_onset=booster_onset, disable_sdlfp=disable_sdlfp, ...)
  mpo <- calculate_nal_sspl90(threshold, gain, ldl, loss, freq)
  
  raw_output <- speech_spec + gain
  overshoot <- pmax(0, raw_output - mpo)
  final_output <- pmin(raw_output, mpo) + (overshoot / 10.0)
  
  final_gain <- pmax(final_output - speech_spec, 0)
  
  if (optimize) {
    # ---------------------------------------------------------
    # 5. Nelder-Mead Optimization subject to Dynamic Loudness Cap
    # ---------------------------------------------------------
    if (file.exists(file.path("data", "critical.rda"))) {
      load(file.path("data", "critical.rda"), envir = environment())
    } else {
      data("critical", package="SII", envir = environment())
    }
    overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
    
    # STATIC PRE-CALCULATIONS
    dense_f <- seq(20, 15000, by = 10)
    local_loss <- if (is.null(loss)) rep(0, length(threshold)) else loss
    dense_abg <- approx(x = log10(freq), y = local_loss, xout = log10(dense_f), rule = 2)$y
    
    hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
    htl <- approx(x = log10(freq), y = threshold, xout = log10(hl_freqs), rule = 2)$y
    sn_htl <- pmax(htl - approx(x = log10(freq), y = local_loss, xout = log10(hl_freqs), rule = 2)$y, 0)
    ohc_loss <- sn_htl
    ihc_loss <- rep(0, length(sn_htl))
    
    sn_octaves <- approx(x = log10(freq), y = (threshold - local_loss), xout = log10(c(500, 1000, 2000, 4000)), rule = 2)$y
    pta_sn_local <- mean(sn_octaves, na.rm = TRUE)
    is_reverse_slope <- sn_octaves[1] > sn_octaves[4] # 500 Hz > 4000 Hz
    
    abg_octaves <- approx(x = log10(freq), y = local_loss, xout = log10(c(500, 1000, 2000, 4000)), rule = 2)$y
    pta_abg_local <- mean(abg_octaves, na.rm = TRUE)
    
    # Helper to run optimization at a specific input level
    optimize_level <- function(eval_level, constraint_gain = NULL) {
      gain_base <- calculate_open_nl_gain(freq=freq, threshold=threshold, input_level=eval_level, gender=gender, experience=experience, config=config, coupling=coupling, module=module, ldl=ldl, loss=loss, distortion_category=distortion_category, user_cr=user_cr, abg_fraction=abg_fraction, enable_severe_booster=enable_severe_booster, booster_onset=booster_onset, disable_sdlfp=disable_sdlfp, ...)
      mpo_base <- calculate_nal_sspl90(threshold, gain_base, ldl, loss, freq)
      
      normal_speech_base <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
      speech_spec_base <- normal_speech_base + (eval_level - overall_normal)
      
      raw_output_base <- speech_spec_base + gain_base
      overshoot_base <- pmax(0, raw_output_base - mpo_base)
      final_output_base <- pmin(raw_output_base, mpo_base) + (overshoot_base / 10.0)
      final_gain_base <- pmax(final_output_base - speech_spec_base, 0)
      
      sii_freqs <- critical$fi
      ltass_base <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
      ltass_eval <- ltass_base + (eval_level - 65)
      
      obj_fn <- function(shifts) {
        out_of_bounds_penalty <- (sum(pmax(0, shifts - 30)^2) + sum(pmax(0, -shifts - 60)^2)) * 1000.0
        clamped_shifts <- pmax(-60, pmin(30, shifts))
        shift_21 <- approx(x = log10(hl_freqs), y = clamped_shifts, xout = log10(freq), rule = 2)$y
        gain_array <- pmax(0, pmin(80, final_gain_base + shift_21))
        
        # --- Guardrails ---
        order_penalty <- 0.0
        cr_penalty <- 0.0
        
        if (!is.null(constraint_gain)) {
          gain_oct <- approx(x = if(length(gain_array)==6) log10(hl_freqs) else log10(freq), y = gain_array, xout = log10(hl_freqs), rule=2)$y
          cg_oct <- approx(x = if(length(constraint_gain)==6) log10(hl_freqs) else log10(freq), y = constraint_gain, xout = log10(hl_freqs), rule=2)$y
          
          # Max shift of 10 dB allows CR up to 3.0. 
          # Max shift of 0 dB forces CR to exactly 1.0 (Linear).
          # We scale this per-frequency based on the proportion of conductive loss.
          # Pure conductive loss (100% ABG) = Linear (0 dB shift).
          # Pure sensorineural (even normal hearing) = Full WDRC (10 dB shift).
          local_loss_oct <- approx(x = if(length(local_loss)==6) log10(hl_freqs) else log10(freq), y = local_loss, xout = log10(hl_freqs), rule=2)$y
          conductive_proportion <- pmin(1.0, pmax(0.0, local_loss_oct / pmax(0.001, htl)))
          sn_proportion <- 1.0 - conductive_proportion
          
          # For soft inputs (50 dB), we restrict the shift to preserve linearity of the ABG restoration,
          # but we must allow up to 15 dB of shift for pure sensorineural losses so they can reach audibility 
          # if the 65 dB target sits very low.
          if (eval_level < 65) {
             max_shift_oct <- sn_proportion * 10.0
          } else if (eval_level > 65) {
             max_shift_oct <- rep(10.0, length(hl_freqs))
          } else {
             max_shift_oct <- sn_proportion * 10.0
          }
          
          if (eval_level < 65) {
            # G_50 >= G_65
            order_penalty <- sum(pmax(0, cg_oct - gain_oct)^2) * 2000.0
            # CR <= Dynamic: G_50 - G_65 <= max_shift
            cr_penalty <- sum(pmax(0, (gain_oct - cg_oct) - max_shift_oct)^2) * 200.0
          } else if (eval_level > 65) {
            # G_80 <= G_65
            order_penalty <- sum(pmax(0, gain_oct - cg_oct)^2) * 2000.0
            # CR <= Dynamic: G_65 - G_80 <= max_shift
            cr_penalty <- sum(pmax(0, (cg_oct - gain_oct) - max_shift_oct)^2) * 200.0
          }
        }
        
        temp_target <- list(
          freq = sii_freqs, 
          gain = approx(x = if(length(gain_array)==6) log10(hl_freqs) else log10(freq), y = gain_array, xout = log10(sii_freqs), rule=2)$y, 
          mpo = approx(x = if(length(mpo_base)==6) log10(hl_freqs) else log10(freq), y = mpo_base, xout = log10(sii_freqs), rule=2)$y, 
          speech = approx(x = log10(freq), y = speech_spec_base, xout = log10(sii_freqs), rule=2)$y,
          threshold = approx(x = log10(freq), y = threshold, xout = log10(sii_freqs), rule=2)$y, 
          loss = approx(x = if(length(loss)==6) log10(hl_freqs) else log10(freq), y = loss, xout = log10(sii_freqs), rule=2)$y, 
          module = module, 
          overall_level = eval_level
        )
        class(temp_target) <- "prescription_target"
        
        res <- tryCatch({
          sii(speech = speech_spec_base, noise = rep(-50, length(freq)), 
              threshold = threshold, loss = loss, freq = freq, 
              prescription = temp_target, interpolate = TRUE, 
              nal_ldf = TRUE, desensitization = "johnson2011_smoothed")
        }, error = function(e) NULL)
        
        if (is.null(res)) return(1000)
        score <- res$sii * 100.0
        
        aided_spl <- ltass_eval + approx(if(length(gain_array)==6) log10(hl_freqs) else log10(freq), gain_array, log10(hl_freqs), rule=2)$y - approx(if(length(local_loss)==6) log10(hl_freqs) else log10(freq), local_loss, log10(hl_freqs), rule=2)$y
        
        f_half <- seq(0, 15000, by = 0.5); f_half[1] <- 1
        li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
        li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
        li[f_half > hl_freqs[6]] <- aided_spl[6] - 24 * log2(f_half[f_half > hl_freqs[6]] / hl_freqs[6])
        overall <- 10 * log10(sum(10^(li / 10)) * 0.5)
        
        
          
          dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y

        dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
        dense_l[dense_f > hl_freqs[6]] <- aided_spl[6] - 24 * log2(dense_f[dense_f > hl_freqs[6]] / hl_freqs[6])
        current_spl <- 10 * log10(sum(10^(dense_l / 10) * 10))
        dense_l <- dense_l + (overall - current_spl)
        
        loud_res <- tryCatch({
          calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l,
            HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss,
            NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)
        }, error = function(e) NULL)
        
        loudness_penalty <- 0.0
        if (!is.null(loud_res)) {
          loudness_sones <- loud_res$Ldn
          
          # Loudness cap knots based on user-provided table
          pta_knots <- c(10, 32.5, 52.5, 72.5, 90)
          
          # U-Shaped Clinical Loudness Tolerance:
          # Normal hearing (PTA=0) tolerates full natural loudness.
          # Mild/Moderate losses (PTA 30-50) have severe recruitment/narrow dynamic ranges, requiring heavy compression (low sones).
          # Severe/Profound losses (PTA 70-90) require raw power just to be audible, necessitating higher loudness caps.
          if (abs(eval_level - 50) < 0.1) {
            cap_knots <- c(1.5, 1.0, 0.8, 1.2, 1.2)
          } else if (abs(eval_level - 80) < 0.1) {
            cap_knots <- c(20.0, 12.0, 10.0, 15.0, 14.0)
          } else { # 65 dB
            cap_knots <- c(7.0, 4.5, 4.0, 6.5, 6.0)
          }
          
          dynamic_cap <- approx(x = pta_knots, y = cap_knots, xout = pta_sn_local, rule = 2)$y
          
          # Reverse slope penalty: If lows are significantly worse than highs,
          # restrict the loud input cap to prevent overamplifying near-normal high frequencies.
          low_hf_diff <- mean(htl[1:2]) - mean(htl[5:6])
          if (low_hf_diff > 10 && eval_level >= 75) {
              dynamic_cap <- dynamic_cap - (low_hf_diff * 0.10)
          }
          
          if (pta_abg_local > 0) {
              if (eval_level >= 75) {
                  # For loud inputs, restrict the loudness cap for mixed losses to avoid overamplification 
                  # and level distortion, bringing gain down closer to NAL-NL2 levels.
                  dynamic_cap <- dynamic_cap - (pta_abg_local * 0.25)
              } else {
                  dynamic_cap <- dynamic_cap + (pta_abg_local * 0.10)
              }
          }
          
          if (loudness_sones > dynamic_cap) {
            excess <- loudness_sones - dynamic_cap
            loudness_penalty <- excess * 2000.0 
          }
        }
        
        overall_spl <- 10 * log10(sum(10^(dense_l / 10) * 10))
        spl_penalty <- 0.0
        if (is.finite(overall_spl) && overall_spl > 110.0) {
          spl_penalty <- (overall_spl - 110.0) * 2000.0
        }
        
        anchor_penalty <- sum(abs(shifts)) * 0.1
        
        # Smoothness penalty to prevent abrupt jumps across frequencies.
        # Scaled down to 0.5 because evaluating diff() on coarse octave bands geometrically 
        # exaggerates the squared penalty for smooth, broad slopes compared to 1/3 octave bands.
        # For mixed/conductive losses, strictly penalize exceeding the anchor (which intrinsically models the 75% ABG rule)
        # to enforce empirical clinical constraints like feedback limits and acclimatization tolerance.
        abg_penalty <- if (any(local_loss > 0)) sum(pmax(0, shifts)^2) * 1.0 else 0

        roughness_penalty <- sum(diff(shifts)^2) * 0.5
        
        return(-score + anchor_penalty + loudness_penalty + out_of_bounds_penalty + spl_penalty + order_penalty + cr_penalty + roughness_penalty + abg_penalty)
      }
      
      best_score <- -obj_fn(rep(0, 6))
      best_shifts <- rep(0, 6)
      
      # Determine the CR to map the 65 dB SPL anchor to the evaluation level
      cr_use <- 1 + pmax(0, sn_htl - 20) / 40
      
      # Ensure deterministic jitter so the 65 dB anchor is strictly identical across runs
      set.seed(as.integer(sum(threshold, na.rm=TRUE) * 100 + eval_level))
      
      # Guarantee audibility for the starting simplex to prevent 0-gradient collapse.
      # We want the starting gain to push the signal to at least threshold + 10 dB.
      # BUT we must respect UCL to avoid triggering the massive loudness penalty!
      estimated_ucl <- 100 + pmax(0, threshold - 60) * 0.25
      target_aided <- pmin(estimated_ucl - 5, pmax(eval_level, threshold + 10))
      target_gain <- target_aided - eval_level
      final_gain_base_interp <- approx(x=log10(freq), y=final_gain_base, xout=log10(hl_freqs), rule=2)$y
      shift_needed <- target_gain - final_gain_base_interp
      
      # Keep shift_needed well within the out_of_bounds_penalty threshold (30 dB)
      start_par <- pmin(20.0, pmax(0, shift_needed))
      if (eval_level < 65) start_par <- start_par + 3.0
      if (eval_level > 65) start_par <- pmax(-10, start_par - 5.0)
      
      for (i in 1:3) {
        current_start_par <- start_par
        
        if (i > 1 || !is.null(seed_noise)) {
          jitter_amount <- if (!is.null(seed_noise)) seed_noise else 5
          current_start_par <- current_start_par + runif(6, -jitter_amount, jitter_amount)
        }
        opt_res <- suppressWarnings(optim(par = current_start_par, fn = obj_fn, method = optim_method, control = list(maxit = 800)))
        current_score <- -opt_res$value
        if (current_score > best_score) {
          best_score <- current_score
          best_shifts <- opt_res$par
        }
      }
      
      clamped_shifts <- pmax(-60, pmin(30, best_shifts))
      best_shifts_21 <- approx(x = log10(hl_freqs), y = clamped_shifts, xout = log10(freq), rule = 2)$y
      final_gain_out <- pmax(0, pmin(80, final_gain_base + best_shifts_21))
      
      # Hard constraint enforcement post-optimization
      if (!is.null(constraint_gain)) {
        # Interpolate max_shift to 21 bands
        sn_loss_local <- pmax(0, threshold - local_loss)
        sn_proportion_local <- ifelse(threshold > 0, sn_loss_local / threshold, 1.0)
        max_shift_oct <- sn_proportion_local * 10.0
        max_shift_interp <- approx(x = log10(hl_freqs), y = max_shift_oct, xout = log10(freq), rule=2)$y
        
        if (eval_level < 65) {
            # G_50 >= G_65
            final_gain_out <- pmax(final_gain_out, constraint_gain)
            # G_50 - G_65 <= max_shift
            final_gain_out <- pmin(final_gain_out, constraint_gain + max_shift_interp)
        } else if (eval_level > 65) {
            # G_80 <= G_65
            final_gain_out <- pmin(final_gain_out, constraint_gain)
            # G_65 - G_80 <= max_shift
            final_gain_out <- pmax(final_gain_out, constraint_gain - max_shift_interp)
        }
      }
      
      return(list(gain = final_gain_out, mpo = mpo_base))
    }
    
    # 1. Optimize 65 dB anchor always
    res_65 <- optimize_level(65, constraint_gain = NULL)
    
    if (abs(overall_level - 65) < 0.1) {
      final_gain <- res_65$gain
    } else {
      # 2. Optimize requested level constrained by 65 dB anchor
      res_requested <- optimize_level(overall_level, constraint_gain = res_65$gain)
      final_gain <- res_requested$gain
    }
    
    convergence_stats <- list(success = TRUE)
  } else {
    convergence_stats <- NULL
  }
  

  # Calculate 1/3-octave Speechmap Output Target
  # ANSI S3.5-1997 1/3-octave band LTASS at 65 dB SPL overall
  ltass_1_3_oct <- c(55.0, 57.5, 51.3, 46.6, 41.6, 36.5)
  ltass_1_3_oct <- ltass_1_3_oct + (overall_level - 65)
  if(length(freq) == 6 && all(freq == c(250, 500, 1000, 2000, 4000, 8000))) {
    speechmap_target <- final_gain + ltass_1_3_oct
  } else {
    ltass_interp <- approx(x = log10(c(250, 500, 1000, 2000, 4000, 8000)), y = ltass_1_3_oct, xout = log10(freq), rule=2)$y
    speechmap_target <- final_gain + ltass_interp
  }
  
  res <- list(
    freq = freq,
    gain = final_gain,
    mpo = mpo,
    speechmap_target = speechmap_target,

    speech = speech_spec,
    threshold = threshold,
    loss = loss,
    module = module,
    overall_level = overall_level,
    convergence_stats = convergence_stats
  )
  class(res) <- "prescription_target"
  return(res)
}

#' @rdname open_nl
#' @export
print.prescription_target <- function(x, ...) {
  cat("Open-NL Prescription Target\n")
  cat(sprintf("Module: %s\n", x$module))
  cat(sprintf("Input Level: %.1f dB SPL\n", x$overall_level))
  cat("\nGain Targets:\n")
  df <- data.frame(Freq = x$freq, Gain = round(x$gain, 1), 
                   Speechmap_SPL = round(x$speechmap_target, 1),
                   MPO = round(x$mpo, 1))
  print(df, row.names = FALSE)
}

#' @rdname open_nl
#' @export
summary.prescription_target <- function(object, ...) {
  print(object)
}

#' @rdname open_nl
#' @export
plot.prescription_target <- function(x, ...) {
  plot(x$freq, x$gain, type="l", log="x", 
       xlab="Frequency (Hz)", ylab="Insertion Gain (dB)",
       main=paste("Open-NL Target (", x$overall_level, " dB SPL)", sep=""),
       ylim=c(0, max(x$gain) + 10))
  points(x$freq, x$gain, pch=16)
  graphics::grid()
}
