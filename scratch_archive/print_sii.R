library(SII)
source("R/benchmark_targets.R")
source("R/open_nl.R")
source("R/nalr.R")
load("data/critical.rda")

p_keys <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
p_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

for (i in 1:7) {
  p <- p_keys[i]
  name <- p_names[i]
  
  freqs <- jd2011_targets[[p]]$freq
  threshold <- jd2011_targets[[p]]$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_spec <- normal_speech + (65 - overall_normal)

  nal_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
  nal_sii_ansi <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nal_tgt, desensitization=FALSE)
  nal_sii_desens <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nal_tgt, desensitization=TRUE)
  
  op_tgt <- opennl_gains[[p]]
  op_sii_ansi <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=op_tgt, desensitization=FALSE)
  op_sii_desens <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=op_tgt, desensitization=TRUE)
  
  cat(paste("|", name, "| NAL-NL2 |", sprintf("%.2f", nal_sii_ansi$sii), "|", sprintf("%.2f", nal_sii_desens$sii), "|", nal_loud[i], "|\n"))
  cat(paste("|", name, "| Open-NL |", sprintf("%.2f", op_sii_ansi$sii), "|", sprintf("%.2f", op_sii_desens$sii), "|", op_loud[i], "|\n"))
}
