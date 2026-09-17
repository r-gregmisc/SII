#!/usr/bin/env Rscript
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

freqs <- c(250,500,1000,2000,4000,8000)

check_case <- function(prof, lvl, use_nal = FALSE, d_scale = 1.0) {
  t_val <- jd2011_targets[[prof]]$threshold
  loss <- rep(0, 6)
  if (prof == "a6") loss <- rep(30, 6)
  if (prof == "a7") loss <- rep(50, 6)
  
  if (use_nal) {
    nal_19 <- get_nalnl2_v2_target(prof, "NAL-NL2", jd2011_targets[[prof]]$freq, lvl)
    gain_vec <- approx(log10(jd2011_targets[[prof]]$freq), nal_19, log10(freqs), rule=2)$y
  } else {
    r0 <- open_nl(speech = lvl, threshold = t_val, freq = freqs, loss = loss, cap_override = 9, vent_floor = 0)
    gain_vec <- r0$gain
  }
  
  speech_spec_base <- build_opennl_speech(freqs, lvl)
  mpo_base <- SII:::calculate_nal_sspl90(t_val, gain_vec, NULL, loss, freqs)
  fi <- critical$fi
  
  temp_target <- list(
    freq = fi,
    gain = approx(log10(freqs), gain_vec, log10(fi), rule=2)$y,
    mpo = approx(log10(freqs), mpo_base, log10(fi), rule=2)$y,
    speech = approx(log10(freqs), speech_spec_base, log10(fi), rule=2)$y,
    threshold = approx(log10(freqs), t_val, log10(fi), rule=2)$y,
    loss = approx(log10(freqs), loss, log10(fi), rule=2)$y,
    module = "standard",
    overall_level = lvl
  )
  class(temp_target) <- "prescription_target"
  
  s_int <- sii(speech = speech_spec_base, noise = rep(-50, 6), 
               threshold = t_val, loss = loss, freq = freqs, 
               prescription = temp_target, interpolate = TRUE, 
               nal_ldf = TRUE, desensitization = "johnson2011_smoothed",
               desensitization_scale = d_scale)$sii
               
  c_int <- sii(speech = speech_spec_base, noise = rep(-50, 6), 
               threshold = t_val, loss = loss, freq = freqs, 
               prescription = temp_target, interpolate = TRUE, 
               nal_ldf = TRUE, desensitization = "johnson2011_complete",
               desensitization_scale = d_scale)$sii
               
  tgt <- build_target(freqs, speech_spec_base, t_val, loss, gain_vec, eval_level = lvl)
  s_rep <- report_sii(tgt, "johnson2011_smoothed", desensitization_scale = d_scale)
  c_rep <- report_sii(tgt, "johnson2011_complete", desensitization_scale = d_scale)
  
  d_s <- abs(s_int - s_rep)
  d_c <- abs(c_int - c_rep)
  
  cat(sprintf("[%s @ %ddB%s d_scale=%.1f] Smooth: Int=%.4f Rep=%.4f | Comp: Int=%.4f Rep=%.4f\n",
              prof, lvl, ifelse(use_nal, " NAL", ""), d_scale, s_int, s_rep, c_int, c_rep))
              
  if (d_s > 0.002 || d_c > 0.002) {
    stop("ERROR: SII difference exceeds 0.002")
  }
}

check_case("a4", 50)
check_case("a4", 65)
check_case("a4", 80)
check_case("a6", 65)
check_case("a4", 65, use_nal = TRUE)
check_case("a4", 65, d_scale = 0.5)

cat("SUCCESS: All cases passed.\n")
