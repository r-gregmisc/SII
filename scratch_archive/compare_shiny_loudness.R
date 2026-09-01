library(SII)
source("R/benchmark_targets.R")
source("R/open_nl.R")
source("R/nalr.R")
load("data/critical.rda")

p_keys <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
p_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

cat("| Profile | Formula | ANSI SII | Johnson 2011_complete SII | Monaural Loudness | Binaural Loudness |\n")
cat("|---|---|---|---|---|---|\n")

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

  # NAL-NL2
  nal_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
  nal_sii_ansi <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nal_tgt, desensitization=FALSE)
  nal_sii_johnson <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nal_tgt, desensitization="johnson2011_complete")
  nal_monaural <- calculate_loudness(nal_sii_ansi)
  nal_monaural <- if(is.list(nal_monaural)) nal_monaural$total else nal_monaural
  nal_binaural <- nal_monaural * 1.75

  cat(sprintf("| %s | NAL-NL2 | %.2f | %.2f | %.2f | %.2f |\n", name, nal_sii_ansi$sii, nal_sii_johnson$sii, nal_monaural, nal_binaural))

  # Open-NL
  op_res <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss)
  op_tgt <- op_res$gain
  op_sii_ansi <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=op_tgt, desensitization=FALSE)
  op_sii_johnson <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=op_tgt, desensitization="johnson2011_complete")
  op_monaural <- calculate_loudness(op_sii_ansi)
  op_monaural <- if(is.list(op_monaural)) op_monaural$total else op_monaural
  op_binaural <- op_monaural * 1.75

  cat(sprintf("| %s | Open-NL | %.2f | %.2f | %.2f | %.2f |\n", name, op_sii_ansi$sii, op_sii_johnson$sii, op_monaural, op_binaural))
}
