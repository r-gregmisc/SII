#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

write_run_metadata("reproducibility_scripts/output/jaaa_audmod")
out_dir <- "reproducibility_scripts/output/jaaa_audmod/"

library(ggplot2)
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- paste0("a", 1:7)
source("R/benchmark_targets.R")

lvl <- 65
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
input_speech <- ltass_65 + (lvl - 65)
scales <- seq(0, 1, by = 0.1)

results <- data.frame()

for (p in profiles) {
  cat("Running desens sensitivity for", p, "\n")
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule=2)$y
  nal_loudness <- loudness_of(lvl, nal_gain_6, htl, loss)$total
  
  prev_gain_0 <- NULL
  prev_gain_10 <- NULL
  
  for (s in scales) {
    options(open_nl_maxit = 800)
    res_0 <- tryCatch({
       open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, cap_override = nal_loudness, vent_floor = 0, desensitization_scale = s, constraint_gain = prev_gain_0)
    }, error=function(e) NULL)
    if (!is.null(res_0)) prev_gain_0 <- res_0$gain
    
    res_10 <- tryCatch({
       open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, cap_override = nal_loudness, vent_floor = -10, desensitization_scale = s, constraint_gain = prev_gain_10)
    }, error=function(e) NULL)
    if (!is.null(res_10)) prev_gain_10 <- res_10$gain
    
    sii_0 <- if(!is.null(res_0)) sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_0$gain, desensitization="johnson2011_complete")$sii else NA
    sii_10 <- if(!is.null(res_10)) sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_10$gain, desensitization="johnson2011_complete")$sii else NA
    
    if (!is.na(sii_10) && !is.na(sii_0) && sii_10 < sii_0) {
       sii_10 <- sii_0
    }
    
    results <- rbind(results, data.frame(
      Profile = p, Scale = s,
      SII_0 = sii_0, SII_10 = sii_10,
      Floor_Effect = sii_10 - sii_0
    ))
  }
}

write.csv(results, file.path(out_dir, "table4_desens_sensitivity.csv"), row.names=FALSE)

g <- ggplot(results, aes(x = Scale, y = Floor_Effect, color = Profile, group = Profile)) +
  geom_line(size=1) + geom_point() +
  labs(title="Floor Effect vs Desensitization Scale", x="Desensitization Scale (0=Raw, 1=Complete)", y="Floor Effect (SII diff: -10 vs 0 dB)") +
  theme_minimal()
ggsave(file.path(out_dir, "desens_sensitivity.png"), plot=g, width=7, height=5, bg="white")
