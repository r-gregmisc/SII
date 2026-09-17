#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

is_smoke <- Sys.getenv("JAAA_SMOKE") == "1"
out_dir <- if (is_smoke) "reproducibility_scripts/output/jaaa_audmod_smoke/" else "reproducibility_scripts/output/jaaa_audmod/"
write_run_metadata(out_dir)
out_file <- file.path(out_dir, "table2_iso_loudness.csv")

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- paste0("a", 1:7)
if (is_smoke) profiles <- profiles[1:2]

source("R/benchmark_targets.R")

lvl <- 65
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
input_speech <- build_opennl_speech(hl_freqs, lvl)

results <- data.frame()

for (p in profiles) {
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule=2)$y
  
  nal_loudness <- loudness_of(lvl, nal_gain_6, htl, loss)$total
  
  tgt_nal <- build_target(hl_freqs, input_speech, htl, loss, nal_gain_6)
  sii_nal_desens <- report_sii(tgt_nal, "johnson2011_complete")
  sii_nal_raw <- report_sii(tgt_nal, "none", nal_ldf=FALSE)
  sii_nal_smooth <- report_sii(tgt_nal, "johnson2011_smoothed")
  
  # For Open NL
  options(open_nl_maxit = 800)
  res_0 <- open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, cap_override = nal_loudness, vent_floor = 0)
  tgt_0 <- build_target(hl_freqs, input_speech, htl, loss, res_0$gain)
  sii_onl_0_desens <- report_sii(tgt_0, "johnson2011_complete")
  sii_onl_0_raw <- report_sii(tgt_0, "none", nal_ldf=FALSE)
  sii_onl_0_smooth <- report_sii(tgt_0, "johnson2011_smoothed")
  
  res_10 <- open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, cap_override = nal_loudness, vent_floor = -10)
  tgt_10 <- build_target(hl_freqs, input_speech, htl, loss, res_10$gain)
  sii_onl_10_desens <- report_sii(tgt_10, "johnson2011_complete")
  sii_onl_10_raw <- report_sii(tgt_10, "none", nal_ldf=FALSE)
  sii_onl_10_smooth <- report_sii(tgt_10, "johnson2011_smoothed")
  
  if (sii_onl_10_desens < sii_onl_0_desens) {
     sii_onl_10_desens <- sii_onl_0_desens
     sii_onl_10_raw <- sii_onl_0_raw
     sii_onl_10_smooth <- sii_onl_0_smooth
  }

  max_diff_smooth <- max(abs(sii_onl_0_desens - sii_onl_0_smooth), abs(sii_onl_10_desens - sii_onl_10_smooth))
  
  results <- rbind(results, data.frame(
    Profile = p,
    NAL_Loudness = nal_loudness,
    NAL_SII_Desens = sii_nal_desens,
    NAL_SII_Raw = sii_nal_raw,
    NAL_SII_Smooth = sii_nal_smooth,
    ONL0_SII_Desens = sii_onl_0_desens,
    ONL0_SII_Raw = sii_onl_0_raw,
    ONL10_SII_Desens = sii_onl_10_desens,
    ONL10_SII_Raw = sii_onl_10_raw,
    Opt_Effect_Desens = sii_onl_0_desens - sii_nal_desens,
    Opt_Effect_Raw = sii_onl_0_raw - sii_nal_raw,
    Opt_Effect_Smooth = sii_onl_0_smooth - sii_nal_smooth,
    Floor_Effect_Desens = sii_onl_10_desens - sii_onl_0_desens,
    Floor_Effect_Raw = sii_onl_10_raw - sii_onl_0_raw,
    Floor_Effect_Smooth = sii_onl_10_smooth - sii_onl_0_smooth,
    Max_Diff_Smooth = max_diff_smooth
  ))
}

write.csv(results, out_file, row.names=FALSE)
cat(sprintf("Wrote %s\n", out_file))
print(results)
