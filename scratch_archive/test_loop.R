library(SII)
source("R/benchmark_targets.R")
source("R/nalr.R")
source("R/open_nl.R")

target_data <- jd2011_targets[["a1"]]
freqs <- target_data$freq
threshold <- target_data$threshold
loss <- rep(0, 6)

data("critical", package="SII")
normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
speech_spec <- normal_speech + (65 - overall_normal)

print(speech_spec)

nalnl2_tgt <- get_jd2011_target("a1", "NAL-NL2", freqs, 65)
obj_nalnl2 <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nalnl2_tgt, desensitization=TRUE)
print(obj_nalnl2$sii)

opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
obj_opennl <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=opennl_tgt$gain, desensitization=TRUE)
print(obj_opennl$sii)

