library(SII)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)
data("critical", package="SII")
normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
speech_spec <- normal_speech + (65 - overall_normal)

htl <- c(15, 20, 30, 40, 50, 60)
gain_nalnl2 <- c(0, 0, 7.3, 12.1, 18, 19.1)
gain_nalr <- c(0, 2.7, 14.8, 15.9, 18, 21.1)
gain_opennl_old <- c(0, 8.25, 16.71, 19.09, 24.3, 13.83)

calc <- function(gain, name) {
  obj <- sii(speech=speech_spec, threshold=htl, loss=rep(0,6), freq=freqs, method="octave", transducer="none", custom_gain=gain, desensitization=FALSE)
  mon <- calculate_loudness(obj)
  bin <- SII:::calculate_binaural_loudness(obj)
  cat(name, "Monaural:", mon, "\n")
  cat(name, "Binaural:", bin, "\n")
}

calc(gain_nalnl2, "NAL-NL2")
calc(gain_nalr, "NAL-R")
calc(gain_opennl_old, "Old Open-NL")
