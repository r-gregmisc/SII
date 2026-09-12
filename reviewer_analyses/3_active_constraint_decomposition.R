# 3_active_constraint_decomposition.R
library(SII)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
threshold_A5 <- c(70, 75, 80, 85, 90, 95) # Profile A5 (Profound)

cat("Running Active-Constraint Decomposition...\n")
tgt <- suppressMessages(open_nl(speech = 80, threshold = threshold_A5, freq = freqs))

# 1. Audibility Cost (Negative SII)
sii_score <- suppressMessages(sii(speech=tgt$speechmap_target, noise=rep(-50,6), threshold=threshold_A5, freq=freqs, interpolate=TRUE))$sii

# 2. Loudness Penalty
dense_f <- seq(20, 15000, by = 10)
dense_l <- approx(x=log10(freqs), y=tgt$speechmap_target, xout=log10(dense_f), rule=2)$y
ohc_loss <- pmax(0, threshold_A5)

loud_res <- suppressWarnings(SII:::calculate_loudness_cpp(
  inputF = dense_f, inputLdB = dense_l,
  HLcf = freqs, HLohcdB0 = ohc_loss, HLihcdB0 = rep(0, 6),
  NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0))

loudness_sones <- loud_res$Ldn
pta <- mean(threshold_A5[2:4])
cap_knots <- c(20.0, 12.0, 10.0, 15.0, 14.0)
pta_knots <- c(10, 32.5, 52.5, 72.5, 90)
dynamic_cap <- approx(x = pta_knots, y = cap_knots, xout = pta, rule = 2)$y

cat(sprintf("Final Prescribed SII:         %.4f\n", sii_score))
cat(sprintf("Final Loudness (Sones):       %.2f\n", loudness_sones))
cat(sprintf("Dynamic Physiological Cap:    %.2f\n", dynamic_cap))

if (loudness_sones > dynamic_cap * 0.95) {
  cat("\nCONCLUSION: The Loudness Penalty is the active constraint!\n")
  cat("The solver successfully maximized audibility until it perfectly collided with the physiological loudness wall.\n")
} else {
  cat("\nCONCLUSION: The Loudness Penalty is inactive. Audibility is limited by compression ratios or hardware max output.\n")
}
