library(devtools)
load_all()

freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
a4_hl <- c(50, 50, 55, 65, 70, 75, 80, 80)
a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)

s_a4 <- sii(speech="normal", threshold=a4_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
cat("A4 SII:", s_a4$sii, "Loudness:", calculate_loudness(s_a4), "\n")

s_a5 <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
cat("A5 SII:", s_a5$sii, "Loudness:", calculate_loudness(s_a5), "\n")
