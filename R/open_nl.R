#' Open-NL WDRC Gain Prescription
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
#'
#' @return An object of class \code{prescription_target}.
#' @export
open_nl <- function(speech = 65, threshold, freq, 
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
  
  gain <- calculate_open_nl_gain(freq, threshold, overall_level, gender, experience, config, coupling, module, ldl, loss, distortion_category, user_cr, abg_fraction, enable_severe_booster, booster_onset = booster_onset, disable_sdlfp = disable_sdlfp)
  mpo <- calculate_nal_sspl90(threshold, gain, ldl, loss, freq)
  
  raw_output <- speech_spec + gain
  overshoot <- pmax(0, raw_output - mpo)
  final_output <- pmin(raw_output, mpo) + (overshoot / 10.0)
  
  final_gain <- pmax(final_output - speech_spec, 0)
  
  if (optimize) {
    # ---------------------------------------------------------
    # 5. Nelder-Mead Optimization subject to Dynamic Loudness Cap
    # ---------------------------------------------------------
    pta_sn <- mean(threshold[c(2, 3, 4, 5)], na.rm = TRUE)
    if (is.na(pta_sn)) pta_sn <- 30
    
    # --- Generate 65 dB SPL Heuristic Seed ---
    # We must explicitly calculate the heuristic at 65 dB SPL to anchor the shifts.
    gain_65 <- calculate_open_nl_gain(freq, threshold, 65, gender, experience, config, coupling, module, ldl, loss, distortion_category, user_cr, abg_fraction, enable_severe_booster, booster_onset = booster_onset)
    mpo_65 <- calculate_nal_sspl90(threshold, gain_65, ldl, loss, freq)
    
    if (file.exists(file.path("data", "critical.rda"))) {
      load(file.path("data", "critical.rda"), envir = environment())
    } else {
      data("critical", package="SII", envir = environment())
    }
    normal_speech_65 <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freq), rule = 2)$y
    overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
    speech_spec_65 <- normal_speech_65 + (65 - overall_normal)
    
    raw_output_65 <- speech_spec_65 + gain_65
    overshoot_65 <- pmax(0, raw_output_65 - mpo_65)
    final_output_65 <- pmin(raw_output_65, mpo_65) + (overshoot_65 / 10.0)
    final_gain_65 <- pmax(final_output_65 - speech_spec_65, 0)
    
    # --- STATIC PRE-CALCULATIONS FOR OBJECTIVE FUNCTION ---
    # Hoisted out of the Nelder-Mead loop for performance
    # MUST be linearly spaced because bramslow2004.cpp assumes a constant df = F[1] - F[0]
    dense_f <- seq(100, 10000, by = 10)
    local_loss <- if (is.null(loss)) rep(0, length(threshold)) else loss
    dense_abg <- approx(x = log10(freq), y = local_loss, xout = log10(dense_f), rule = 2)$y
    
    hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
    htl <- approx(x = log10(freq), y = threshold, xout = log10(hl_freqs), rule = 2)$y
    sn_htl <- pmax(htl - approx(x = log10(freq), y = local_loss, xout = log10(hl_freqs), rule = 2)$y, 0)
    ohc_loss <- sn_htl
    ihc_loss <- rep(0, length(sn_htl))
    # ------------------------------------------------------
    
    obj_fn <- function(shifts) {
      # Add a massive penalty for shifts outside +10 / -30 dB to anchor to clinical heuristic
      out_of_bounds_penalty <- (sum(pmax(0, shifts - 10)^2) + sum(pmax(0, -shifts - 30)^2)) * 1000.0
      
      clamped_shifts <- pmax(-30, pmin(10, shifts))
      gain_array <- pmax(0, pmin(80, final_gain_65 + clamped_shifts))
      
      # We evaluate the objective function at 65 dB SPL (Standard Speech) to align with
      # clinical conventions and JASA reviewer expectations.
      eval_level <- 65
      
      temp_target <- list(
        freq = freq, gain = gain_array, mpo = mpo_65, speech = speech_spec_65,
        threshold = threshold, loss = loss, module = module, overall_level = eval_level
      )
      class(temp_target) <- "prescription_target"
      
      # Maximize Audibility with NAL-NL2 modified LDF
      res <- tryCatch({
        sii(speech = speech_spec_65, noise = rep(-50, length(freq)), 
            threshold = threshold, loss = loss, freq = freq, 
            prescription = temp_target, interpolate = TRUE, 
            nal_ldf = TRUE, desensitization = "johnson2011_smoothed")
      }, error = function(e) NULL)
      
      if (is.null(res)) return(1000)

      score <- res$sii * 100.0
      
      # Chen 2011 loudness (100 points for optimizer speed)
      fi <- res$table[, "Fi"]
      Ei <- res$table[, "E'i"]
      dense_l <- approx(x = log10(fi), y = Ei, xout = log10(dense_f), rule = 1)$y
      idx_low <- which(dense_f < fi[1])
      if (length(idx_low) > 0) dense_l[idx_low] <- Ei[1] - 24 * log2(fi[1] / dense_f[idx_low])
      idx_high <- which(dense_f > fi[length(fi)])
      if (length(idx_high) > 0) dense_l[idx_high] <- Ei[length(Ei)] - 24 * log2(dense_f[idx_high] / fi[length(fi)])
      dense_l[is.na(dense_l)] <- -100
      

      
      dense_l <- dense_l - dense_abg
      
      loud_res <- tryCatch({
        calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l,
          HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss,
          NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)
      }, error = function(e) NULL)
      
      loudness_penalty <- 0.0
      if (!is.null(loud_res)) {
        loudness_sones <- loud_res$Ldn
        sn_threshold <- threshold - local_loss
        pta_sn_local <- mean(sn_threshold[c(2, 3, 4, 5)], na.rm = TRUE)
        
        # Clinical Heuristic: Reverse-slope losses (LF > HF) suffer from upward spread of 
        # masking. NAL-NL2 inherently limits LF gain, resulting in much lower loudness. 
        # To prevent SII maximization from over-amplifying low frequencies, we enforce a 
        # stricter dynamic cap for reverse-slope profiles.
        is_reverse_slope <- sn_threshold[2] > sn_threshold[5] # 500 Hz > 4000 Hz
        if (is_reverse_slope) {
            dynamic_cap <- max(4.0, 1.5 + 0.08 * pta_sn_local)
        } else {
            dynamic_cap <- max(6.5, 2.5 + 0.12 * pta_sn_local)
        }
        
        if (loudness_sones > dynamic_cap) {
          excess <- loudness_sones - dynamic_cap
          loudness_penalty <- excess * 500.0 
        }
      }
      
      # Safety Limit: Real hearing aids restrict Maximum Power Output (MPO) to 
      # prevent hazardous exposure. If the optimizer boosts dead regions, loudness 
      # won't increase but physical SPL will. This SPL limit prevents the Octave 
      # bramslow2004 C-engine from crashing due to >120 dB SPL signals.
      # dense_l is power density per Hz, and we have a 10 Hz resolution
      overall_spl <- 10 * log10(sum(10^(dense_l / 10) * 10))
      spl_penalty <- 0.0
      if (is.finite(overall_spl) && overall_spl > 110.0) {
        spl_penalty <- (overall_spl - 110.0) * 500.0
      }
      
      # Soft Anchor Penalty to prevent drifting in regions where SII plateaus
      anchor_penalty <- sum(abs(shifts)) * 0.1
      
      return(-score + anchor_penalty + loudness_penalty + out_of_bounds_penalty + spl_penalty)
    }
    
    # Multi-start Nelder-Mead optimization (5 iterations, 150 max iter per run)
    # Mitigates initialization sensitivity near the recruitment boundary
    num_starts <- 5
    best_val <- Inf
    best_shifts <- rep(0, length(freq))
    convergence_codes <- integer(num_starts)
    obj_values <- numeric(num_starts)
    
    for (i in seq_len(num_starts)) {
      start_par <- rep(0, length(freq))
      # Apply random uniform jitter to mitigate initialization sensitivity
      # Jitter is applied on all iterations except the first (which uses the pure baseline)
      if (i > 1 || !is.null(seed_noise)) {
        jitter_amount <- if (!is.null(seed_noise)) seed_noise else 5
        start_par <- start_par + runif(length(freq), -jitter_amount, jitter_amount)
      }
      
      opt_res <- suppressWarnings(optim(
        par = start_par, 
        fn = obj_fn, 
        method = optim_method, 
        control = list(maxit = 150)
      ))
      
      convergence_codes[i] <- opt_res$convergence
      obj_values[i] <- opt_res$value
      
      if (opt_res$value < best_val) {
        best_val <- opt_res$value
        best_shifts <- opt_res$par
      }
    }
    
    convergence_stats <- list(
      success_rate = sum(convergence_codes == 0) / num_starts,
      variance = if (num_starts > 1) var(obj_values) else 0,
      best_value = best_val,
      codes = convergence_codes
    )
    
    constrained_best_shifts <- pmax(-30, pmin(10, best_shifts))
    
    # Apply the 65 dB optimal shifts to the dynamically scaled heuristic target
    # This preserves the exact WDRC compression ratios (the difference between 50, 65, and 80 dB targets)
    final_gain <- pmax(0, pmin(80, final_gain + constrained_best_shifts))
  } else {
    convergence_stats <- NULL
  }
  
  res <- list(
    freq = freq,
    gain = final_gain,
    mpo = mpo,
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

#' @export
print.prescription_target <- function(x, ...) {
  cat("Open-NL Prescription Target\n")
  cat(sprintf("Module: %s\n", x$module))
  cat(sprintf("Input Level: %.1f dB SPL\n", x$overall_level))
  cat("\nGain Targets:\n")
  df <- data.frame(Freq = x$freq, Gain = round(x$gain, 1), MPO = round(x$mpo, 1))
  print(df, row.names = FALSE)
}

#' @export
summary.prescription_target <- function(object, ...) {
  print(object)
}

#' @export
plot.prescription_target <- function(x, ...) {
  plot(x$freq, x$gain, type="l", log="x", 
       xlab="Frequency (Hz)", ylab="Insertion Gain (dB)",
       main=paste("Open-NL Target (", x$overall_level, " dB SPL)", sep=""),
       ylim=c(0, max(x$gain) + 10))
  points(x$freq, x$gain, pch=16)
  graphics::grid()
}
