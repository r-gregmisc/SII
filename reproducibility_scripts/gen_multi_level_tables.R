#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

is_smoke <- Sys.getenv("JAAA_SMOKE") == "1"
out_dir <- if (is_smoke) "reproducibility_scripts/output/jaaa_audmod_smoke/" else "reproducibility_scripts/output/jaaa_audmod/"
write_run_metadata(out_dir)
out_file <- file.path(out_dir, "table3_multi_level.md")

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1 (Mild)", "A2 (Rev Slope)", "A3 (Mod Sloping)", "A4 (Mod-Severe)", "A5 (Profound)", "A6 (Mixed)", "A7 (Conductive)")
source("R/benchmark_targets.R")

sink(out_file)
cat("| Profile | Input (dB SPL) | Method | ANSI SII | Effective SII | Sones | Gains |\n")
cat("|---|---|---|---|---|---|---|\n")

for (i in if(is_smoke) 1:2 else 1:7) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- target_data$freq
  threshold_6 <- target_data$threshold
  loss_6 <- rep(0, 6)
  if (p == "a6") loss_6 <- rep(30, 6)
  if (p == "a7") loss_6 <- rep(50, 6)
  
  for (lvl in c(50, 65, 80)) {
      onl_res <- open_nl(speech = lvl, threshold = threshold_6, freq = hl_freqs, loss = loss_6)
      onl_gain_6 <- onl_res$gain
      
      nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, lvl)
      nal_gain_6 <- approx(log10(freqs), nal_gain_19, log10(hl_freqs), rule=2)$y
      

      speech_spec <- build_opennl_speech(hl_freqs, lvl)
      
      tgt_onl <- build_target(hl_freqs, speech_spec, threshold_6, loss_6, onl_gain_6, eval_level=lvl)
      ansi_sii_onl <- report_sii(tgt_onl, "none", nal_ldf=FALSE)
      tgt_nal <- build_target(hl_freqs, speech_spec, threshold_6, loss_6, nal_gain_6, eval_level=lvl)
      ansi_sii_nal <- report_sii(tgt_nal, "none", nal_ldf=FALSE)
      
      eff_sii_onl <- report_sii(tgt_onl, "johnson2011_desensitized")
      eff_sii_nal <- report_sii(tgt_nal, "johnson2011_desensitized")
      
      sones_onl <- loudness_of(lvl, onl_gain_6, threshold_6, loss_6)$total
      sones_nal <- loudness_of(lvl, nal_gain_6, threshold_6, loss_6)$total
      
      cat(sprintf("| %s | %d | NAL-NL2 | %.3f | %.3f | %.2f | %.1f, %.1f, %.1f, %.1f, %.1f, %.1f |\n", p_name, lvl, ansi_sii_nal, eff_sii_nal, sones_nal, nal_gain_6[1], nal_gain_6[2], nal_gain_6[3], nal_gain_6[4], nal_gain_6[5], nal_gain_6[6]))
      cat(sprintf("| %s | %d | Open-NL | %.3f | %.3f | %.2f | %.1f, %.1f, %.1f, %.1f, %.1f, %.1f |\n", p_name, lvl, ansi_sii_onl, eff_sii_onl, sones_onl, onl_gain_6[1], onl_gain_6[2], onl_gain_6[3], onl_gain_6[4], onl_gain_6[5], onl_gain_6[6]))
  }
}
sink()
cat(sprintf("Wrote %s\n", out_file))
