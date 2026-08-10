library(devtools)
load_all(".")

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
a5 <- c(10, 10, 20, 60, 80, 100)

tgt <- open_nl(65, threshold = a5, freq = freqs)
res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = a5, freq = freqs, prescription = NULL, method = "octave")

sii_val <- res$sii
sones_val <- calculate_loudness(res)

cat(sprintf("\n--- RESULT ---\nSII: %.3f\nSones: %.1f\n", sii_val, sones_val))
