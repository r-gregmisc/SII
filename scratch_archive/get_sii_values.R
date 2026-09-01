library(SII)
source("R/benchmark_targets.R")
source("R/open_nl.R")
source("R/nalr.R")
load("data/critical.rda")

p_keys <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
p_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

cat("| Profile | Formula | ANSI SII | Desensitized SII | Monaural Loudness (Sones) |\n")
cat("|---|---|---|---|---|\n")

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

  # Calculate NAL-NL2 dynamically
  nal_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
  nal_sii <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nal_tgt, desensitization=TRUE)
  nal_loudness <- calculate_loudness(nal_sii)
  nal_loudness <- if(is.list(nal_loudness)) nal_loudness$total else nal_loudness

  # Calculate Open-NL dynamically (instead of hardcoded array)
  op_res <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss)
  op_tgt <- op_res$gain
  
  op_sii <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=op_tgt, desensitization=TRUE)
  op_loudness <- calculate_loudness(op_sii)
  op_loudness <- if(is.list(op_loudness)) op_loudness$total else op_loudness
  
  cat(sprintf("| %s | NAL-NL2 | %.2f | %.2f | %.1f |\n", name, nal_sii$sii, nal_sii$desensitized_sii, nal_loudness))
  cat(sprintf("| %s | Open-NL | %.2f | %.2f | %.1f |\n", name, op_sii$sii, op_sii$desensitized_sii, op_loudness))
}
