library(SII)
source("R/sii.R")
source("R/open_nl.R")

htl <- c(15, 20, 30, 40, 50, 60)
cond <- rep(0, 6)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)

target_opennl_6 <- c(0, 8.25, 16.71, 19.09, 24.3, 13.83)

critical <- SII:::sii_bands$critical
normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule=2)$y
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm=TRUE))
speech_spec <- normal_speech + (65 - overall_normal)

sii_obj <- sii(speech=speech_spec, threshold=htl, loss=cond, freq=freqs, method="octave", transducer="none", custom_gain=target_opennl_6, desensitization=FALSE)
val <- calculate_loudness(sii_obj)$total
cat(sprintf("Loudness for this exact Shiny vector is: %.2f\n", val))
