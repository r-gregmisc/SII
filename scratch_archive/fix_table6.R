library(SII)
source("R/benchmark_targets.R")
source("R/open_nl.R")

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

cat("| Profile | Formula | ANSI SII | Desensitized SII | Monaural Loudness (Sones) |\n")
cat("|---|---|---|---|---|\n")

for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- target_data$freq
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  # NAL-NL2
  nalnl2_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
  obj_nalnl2 <- sii(speech=65, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nalnl2_tgt)
  
  # Open-NL (We just need to know its SII for the generated targets)
  # Actually, since OpenNL targets are in Table VII already, let's grab them.
  # Let's run Open-NL to get the target
  opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  obj_opennl <- sii(speech=65, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=opennl_tgt$gain)
  
  cat(sprintf("| %s | NAL-NL2 | %.2f | %.2f |  |\n", p_name, obj_nalnl2$sii, obj_nalnl2$desensitized_sii))
  cat(sprintf("| %s | Open-NL | %.2f | %.2f |  |\n", p_name, obj_opennl$sii, obj_opennl$desensitized_sii))
}
