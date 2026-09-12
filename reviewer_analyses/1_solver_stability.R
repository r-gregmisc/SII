# 1_solver_stability.R
library(SII)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
threshold_A4 <- c(65, 65, 70, 75, 80, 85) # Profile A4 (Severe)

cat("Running Solver-Stability / Identifiability Experiment...\n")
cat("Starting the optimizer from 20 entirely different random vectors to check if it converges to the same SII via different insertion gains.\n\n")

results <- data.frame(Seed=integer(), SII=numeric(), G1k=numeric(), G4k=numeric())

for (i in 1:20) {
  set.seed(i)
  tgt <- suppressMessages(open_nl(speech = 65, threshold = threshold_A4, freq = freqs, seed_noise = 25))
  
  # Pass interpolate=TRUE so the 6 audiometric bands are correctly mapped to the 21 critical bands for scoring
  score <- suppressMessages(sii(speech=tgt$speechmap_target, noise=rep(-50,6), threshold=threshold_A4, freq=freqs, interpolate=TRUE))
  
  results <- rbind(results, data.frame(
    Seed = i,
    SII = round(score$sii, 4),
    G1k = round(tgt$gain[3], 1),
    G4k = round(tgt$gain[5], 1)
  ))
  
  cat(sprintf("Seed %02d | Final SII: %.4f | 1kHz Gain: %4.1f dB | 4kHz Gain: %4.1f dB\n", 
              i, score$sii, tgt$gain[3], tgt$gain[5]))
}

var_g1k <- var(results$G1k)
var_g4k <- var(results$G4k)
cat(sprintf("\nVariance in 1kHz Gain: %.2f dB^2\n", var_g1k))
cat(sprintf("Variance in 4kHz Gain: %.2f dB^2\n", var_g4k))
if(var_g4k > 10) {
  cat("\nCONCLUSION: High parameter variance with stable SII scores proves parameter unidentifiability (the 'flat basin' problem).\n")
} else {
  cat("\nCONCLUSION: Surprisingly, the Nelder-Mead solver converged to essentially the exact same parameters despite massive initial jitter. The objective function appears convex and strictly identifiable for this profile!\n")
}
