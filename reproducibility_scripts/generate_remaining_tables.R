#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

write_run_metadata("reproducibility_scripts/output/jaaa_audmod")
out_file <- "reproducibility_scripts/output/jaaa_audmod/table_remaining.md"

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

source("R/benchmark_targets.R")

sink(out_file)
cat("\n### Table II Markdown Output (Seeds):\n")
cat("| Profile | Unconstrained SII | Unconstrained Sones | Constrained SII | Constrained Sones |\n")
cat("|---|---|---|---|---|\n")
for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  # Unconstrained (disable_sdlfp=TRUE)
  seed_unconstrained <- SII:::calculate_open_nl_gain(freq=freqs, threshold=threshold, input_level=65, loss=loss, enable_severe_booster=TRUE, booster_onset=60, disable_sdlfp=TRUE)
  obj_raw_unconstrained <- sii(speech=c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold=threshold, loss=loss, freq=freqs, custom_gain=seed_unconstrained, method="octave", transducer="none", desensitization="none")
  sones_unconstrained <- loudness_of(65, seed_unconstrained, threshold, loss)$total

  # Constrained (disable_sdlfp=FALSE)
  seed_constrained <- SII:::calculate_open_nl_gain(freq=freqs, threshold=threshold, input_level=65, loss=loss, enable_severe_booster=TRUE, booster_onset=60, disable_sdlfp=FALSE)
  obj_raw_constrained <- sii(speech=c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold=threshold, loss=loss, freq=freqs, custom_gain=seed_constrained, method="octave", transducer="none", desensitization="none")
  sones_constrained <- loudness_of(65, seed_constrained, threshold, loss)$total

  cat(sprintf("| %s | %.2f | %.1f | %.2f | %.1f |\n", p_name, obj_raw_unconstrained$sii, sones_unconstrained, obj_raw_constrained$sii, sones_constrained))
}


cat("\n### Table VII Markdown Output:\n")
cat("| Profile | Formula | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |\n")
cat("|---|---|---|---|---|---|---|---|\n")
for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  nalnl2_tgt <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, 65)
  opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  
  cat(sprintf("| %s | NAL-NL2 | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n", 
              p_name, nalnl2_tgt[1], nalnl2_tgt[2], nalnl2_tgt[3], 
              nalnl2_tgt[4], nalnl2_tgt[5], nalnl2_tgt[6]))
              
  cat(sprintf("|  | Open-NL | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n", 
              opennl_tgt$gain[1], opennl_tgt$gain[2], opennl_tgt$gain[3], 
              opennl_tgt$gain[4], opennl_tgt$gain[5], opennl_tgt$gain[6]))
}
sink()
cat(sprintf("Wrote %s\n", out_file))
