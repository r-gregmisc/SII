library(SII)
source("R/benchmark_targets.R")
load("data/critical.rda")
p <- "a1"
freqs <- jd2011_targets[[p]]$freq
threshold <- jd2011_targets[[p]]$threshold
loss <- rep(0, 6)
normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
speech_spec <- normal_speech + (65 - overall_normal)
nal_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
nal_sii <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nal_tgt, desensitization=TRUE)
print(names(nal_sii))
