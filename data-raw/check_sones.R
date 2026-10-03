library(SII)
source("R/benchmark_targets.R")

Rcpp::sourceCpp("src/bramslow2004.cpp")

cat("Profile\tMethod\tANSI_SII\tEff_SII\tCPP_Sones\n")
cat("--------------------------------------------------\n")

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
for (p in profiles) {
  loss <- jd2011_targets[[p]]$threshold
  cond <- jd2011_targets[[p]]$loss
  if (is.null(cond)) cond <- rep(0, length(loss))
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  # Calculate Open-NL
  # optimize=TRUE uses johnson2011_smoothed internally
  open_nl_tgt <- open_nl(speech = 65, threshold = loss, freq = freqs, loss = cond, optimize=TRUE)
  
  # Calculate NAL-NL2 from our newly updated jd2011_targets
  nal_tgt <- jd2011_targets[[p]]$nalnl2
  
  # We construct a fake prescription_target for NAL-NL2 just to pass it into sii() easily
  temp_nal <- list(
    freq = freqs, gain = nal_tgt, mpo = rep(120, 6), speech = open_nl_tgt$speech,
    threshold = loss, loss = cond, module = "standard", overall_level = 65
  )
  class(temp_nal) <- "prescription_target"
  
  # 1. Evaluate Open-NL
  # ANSI SII (no desensitization)
  sii_open_ansi <- sii(speech = open_nl_tgt$speech, threshold = loss, freq = freqs, loss = cond, prescription = open_nl_tgt, desensitization = "none", interpolate = TRUE)
  # Effective SII (complete)
  sii_open_eff <- sii(speech = open_nl_tgt$speech, threshold = loss, freq = freqs, loss = cond, prescription = open_nl_tgt, desensitization = "johnson2011_complete", interpolate = TRUE)
  # C++ Sones
  l_open <- SII:::calculate_loudness(sii_open_eff)$total
  
  # 2. Evaluate NAL-NL2
  sii_nal_ansi <- sii(speech = open_nl_tgt$speech, threshold = loss, freq = freqs, loss = cond, prescription = temp_nal, desensitization = "none", interpolate = TRUE)
  sii_nal_eff <- sii(speech = open_nl_tgt$speech, threshold = loss, freq = freqs, loss = cond, prescription = temp_nal, desensitization = "johnson2011_complete", interpolate = TRUE)
  l_nal <- SII:::calculate_loudness(sii_nal_eff)$total
  
  cat(sprintf("%s\tNAL-NL2\t%.3f\t%.3f\t%.2f\n", toupper(p), sii_nal_ansi$sii, sii_nal_eff$sii, l_nal))
  cat(sprintf("%s\tOpen-NL\t%.3f\t%.3f\t%.2f\n", toupper(p), sii_open_ansi$sii, sii_open_eff$sii, l_open))
  cat("--------------------------------------------------\n")
}
