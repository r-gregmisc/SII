#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

write_run_metadata("reproducibility_scripts/output/jaaa_audmod")
out_file <- "reproducibility_scripts/output/jaaa_audmod/table2_iso_loudness.csv"

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c(paste0("a", 1:7))

source("R/benchmark_targets.R")

lvl <- 65
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
input_speech <- ltass_65 + (lvl - 65)

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
  
  sii_nal_desens <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=nal_gain_6, desensitization="johnson2011_complete")$sii
  sii_nal_raw <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=nal_gain_6, desensitization="none")$sii
  
  # For Open NL
  options(open_nl_maxit = 800)
  res_0 <- open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, cap_override = nal_loudness, vent_floor = 0)
  sii_onl_0_desens <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_0$gain, desensitization="johnson2011_complete")$sii
  sii_onl_0_raw <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_0$gain, desensitization="none")$sii
  sii_onl_0_smooth <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_0$gain, desensitization="johnson2011_smoothed")$sii
  
  res_10 <- open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, cap_override = nal_loudness, vent_floor = -10, constraint_gain = res_0$gain)
  sii_onl_10_desens <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_10$gain, desensitization="johnson2011_complete")$sii
  sii_onl_10_raw <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_10$gain, desensitization="none")$sii
  sii_onl_10_smooth <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_10$gain, desensitization="johnson2011_smoothed")$sii
  
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
    ONL0_SII_Desens = sii_onl_0_desens,
    ONL0_SII_Raw = sii_onl_0_raw,
    ONL10_SII_Desens = sii_onl_10_desens,
    ONL10_SII_Raw = sii_onl_10_raw,
    Opt_Effect_Desens = sii_onl_0_desens - sii_nal_desens,
    Opt_Effect_Raw = sii_onl_0_raw - sii_nal_raw,
    Floor_Effect_Desens = sii_onl_10_desens - sii_onl_0_desens,
    Floor_Effect_Raw = sii_onl_10_raw - sii_onl_0_raw,
    Max_Diff_Smooth = max_diff_smooth
  ))
}

write.csv(results, out_file, row.names=FALSE)
cat(sprintf("Wrote %s\n", out_file))
print(results)
