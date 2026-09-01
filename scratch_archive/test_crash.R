library(SII)
source("R/benchmark_targets.R")
source("R/open_nl.R")
source("R/nalr.R")
load("data/critical.rda")

p_keys <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
p_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

for (i in 1:1) {
  p <- p_keys[i]
  name <- p_names[i]
  freqs <- jd2011_targets[[p]]$freq
  threshold <- jd2011_targets[[p]]$threshold
  loss <- rep(0, 6)
  
  cat("A\n")
  normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_spec <- normal_speech + (65 - overall_normal)
  
  cat("B\n")
  nal_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
  cat("C\n")
  nal_sii <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nal_tgt, desensitization="johnson2011_complete")
  cat("D\n")
}
