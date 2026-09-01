devtools::load_all(".", quiet=TRUE)
source("R/benchmark_targets.R")

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

cat("\n### Table VI Markdown Output:\n")
for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  
  # NAL-NL2 Target
  nalnl2_tgt <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, 65)
  obj_nalnl2 <- sii(speech=input_speech, noise=rep(-50,6), threshold=threshold, loss=loss, freq=freqs, custom_gain=nalnl2_tgt, method="octave", transducer="none", desensitization=TRUE)
  obj_nalnl2_raw <- sii(speech=input_speech, noise=rep(-50,6), threshold=threshold, loss=loss, freq=freqs, custom_gain=nalnl2_tgt, method="octave", transducer="none", desensitization=FALSE)
  
  # Package dummy object for new calculate_loudness API
  nalnl2_obj <- list(gain=nalnl2_tgt, freq=freqs, threshold=threshold, loss=loss, vocal_effort="65 dB SPL")
  nalnl2_sones <- calculate_loudness(nalnl2_obj)$total

  # Open-NL Target
  opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  obj_opennl_raw <- sii(speech=input_speech, noise=rep(-50,6), threshold=threshold, loss=loss, freq=freqs, prescription=opennl_tgt, method="octave", transducer="none", desensitization=FALSE)
  obj_opennl_des <- sii(speech=input_speech, noise=rep(-50,6), threshold=threshold, loss=loss, freq=freqs, prescription=opennl_tgt, method="octave", transducer="none", desensitization=TRUE)
  
  opennl_sones <- calculate_loudness(opennl_tgt)$total

  cat(sprintf("| %s | NAL-NL2 | %.2f | %.2f | %.1f |\n", p_name, obj_nalnl2_raw$sii, obj_nalnl2$sii, nalnl2_sones))
  cat(sprintf("| %s | Open-NL | %.2f | %.2f | %.1f |\n", p_name, obj_opennl_raw$sii, obj_opennl_des$sii, opennl_sones))
}

cat("\n### Table VII Markdown Output:\n")
for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  
  cat(sprintf("| %s (Open-NL) | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n", 
              p_name, opennl_tgt$gain[1], opennl_tgt$gain[2], opennl_tgt$gain[3], 
              opennl_tgt$gain[4], opennl_tgt$gain[5], opennl_tgt$gain[6]))
}
