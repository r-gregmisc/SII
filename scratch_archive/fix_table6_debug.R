library(SII)
source("R/benchmark_targets.R")

opennl_gains <- list(
  a1 = c(0.0, 7.2, 15.8, 18.4, 22.0, 12.8),
  a2 = c(11.8, 18.0, 20.4, 13.8, 8.2, 2.5),
  a3 = c(0.0, 7.2, 20.4, 23.0, 24.3, 12.8),
  a4 = c(0.0, 0.0, 6.6, 18.4, 32.7, 18.9),
  a5 = c(0.0, 0.0, 11.2, 27.6, 38.8, 23.5),
  a6 = c(16.3, 29.0, 38.3, 38.6, 42.2, 33.0),
  a7 = c(24.9, 32.5, 39.5, 37.5, 36.5, 36.5)
)

cat("Loading critical...\n")
load("data/critical.rda")
cat("Critical loaded. Classes: ", class(critical), "\n")

p <- "a1"
freqs <- jd2011_targets[[p]]$freq
threshold <- jd2011_targets[[p]]$threshold
loss <- rep(0, 6)

cat("Calculating normal speech...\n")
normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
speech_spec <- normal_speech + (65 - overall_normal)

cat("Getting NAL-NL2 target...\n")
nalnl2_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)

cat("Calculating SII NAL-NL2...\n")
obj_nalnl2 <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nalnl2_tgt, desensitization=TRUE)
cat("NAL-NL2 SII: ", obj_nalnl2$sii, "\n")

cat("Calculating SII Open-NL...\n")
op_gain <- opennl_gains[[p]]
obj_opennl <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=op_gain, desensitization=TRUE)
cat("Open-NL SII: ", obj_opennl$sii, "\n")

cat("SUCCESS!\n")
