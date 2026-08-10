library(devtools)
load_all()
if (file.exists(file.path("data", "critical.rda"))) {
  load(file.path("data", "critical.rda"))
}
freqs = critical$fi
normal_speech = critical$normal
overall_normal = 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
speech_spec = normal_speech + (65 - overall_normal)
cat("Freq,Level\n", file="speech_spectrum_65.csv")
for(i in 1:length(freqs)){
  cat(sprintf("%f,%f\n", freqs[i], speech_spec[i]), file="speech_spectrum_65.csv", append=TRUE)
}
cat("speech_spectrum_65.csv generated.\n")
