library(devtools)
load_all()

freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)

# A4: Severe Flat Loss
a4_hl <- c(50, 50, 55, 65, 70, 75, 80, 80)
s_a4 <- sii(speech="normal", threshold=a4_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
l_a4 <- calculate_loudness(s_a4)

# A5: Profound Sloping Loss
a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)
s_a5 <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
l_a5 <- calculate_loudness(s_a5)

cat("\n--- Open-NL LDN-H Results ---\n")
cat(sprintf("A4 (Severe Flat)   -> SII: %.2f | Loudness: %.1f sones\n", s_a4$sii, l_a4))
cat(sprintf("A5 (Profound Slope)-> SII: %.2f | Loudness: %.1f sones\n", s_a5$sii, l_a5))
cat(sprintf("A4 Insertion Gain at 4kHz: %.1f dB\n", s_a4$prescription_target$gain[6]))
cat(sprintf("A5 Insertion Gain at 4kHz: %.1f dB\n", s_a5$prescription_target$gain[6]))
cat("-------------------------------\n")
