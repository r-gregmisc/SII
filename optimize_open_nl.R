library(devtools)
load_all()

cat("=========================================\n")
cat("OPEN-NL DIAGNOSTIC SUITE (A4 / A5)\n")
cat("=========================================\n")

freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
a4_hl <- c(50, 50, 55, 65, 70, 75, 80, 80)
a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)

cat("\n--- A4 DIAGNOSTICS ---\n")
s_a4 <- sii(speech="normal", threshold=a4_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
l_a4 <- calculate_loudness(s_a4)
cat(sprintf("A4 Current Final -> SII: %.2f | Loudness: %.1f sones\n", s_a4$sii, l_a4))

cat("\n--- A5 DIAGNOSTICS ---\n")
s_a5 <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)
l_a5 <- calculate_loudness(s_a5)
cat(sprintf("A5 Current Final -> SII: %.2f | Loudness: %.1f sones\n", s_a5$sii, l_a5))

# We will print the internal IG from calculate_open_nl_gain
ig_a4 <- calculate_open_nl_gain(freqs, a4_hl, input_level=65)
cat("\nA4 Prescribed Insertion Gain (IG) per freq:\n")
cat(paste(round(ig_a4, 1), collapse=", "), "\n")

ig_a5 <- calculate_open_nl_gain(freqs, a5_hl, input_level=65)
cat("A5 Prescribed Insertion Gain (IG) per freq:\n")
cat(paste(round(ig_a5, 1), collapse=", "), "\n")

# Predict LDL and SSPL90 for A5
predict_ldl <- function(htl) { 100 + pmax(0, htl - 40) * 0.5 }
cat("\nA5 Predicted LDL:\n")
cat(paste(round(predict_ldl(a5_hl), 1), collapse=", "), "\n")

sspl90_a5 <- 90 + ig_a5 - 5
cat("A5 Projected SSPL90 Output (90 + IG - 5):\n")
cat(paste(round(sspl90_a5, 1), collapse=", "), "\n")

mpo_ceiling <- predict_ldl(a5_hl) - 12
cat("A5 MPO Ceiling (LDL - 12):\n")
cat(paste(round(mpo_ceiling, 1), collapse=", "), "\n")
