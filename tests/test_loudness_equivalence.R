library(SII)

# The C++ engine is already loaded natively by the package
cat("Using internal C++ engine...\n")

# Define a standard audiogram grid
HLcf <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)

cat("\n======================================================\n")
cat("=== Bramslow 2004 C++ Loudness Engine Verification ===\n")
cat("======================================================\n\n")

# Test 1: Normal Hearing (0 dB HL)
cat("--- TEST 1: Normal Hearing (0 dB HL) at 1 kHz ---\n")
HLohcdB0_NH <- rep(0, length(HLcf))
HLihcdB0_NH <- rep(0, length(HLcf))

levels <- c(30, 50, 65, 80, 100)

for (L in levels) {
  inputF <- c(1000)
  inputLdB <- c(L)
  
  res <- calculate_loudness_cpp(inputF, inputLdB, HLcf, HLohcdB0_NH, HLihcdB0_NH)
  
  cat(sprintf("Input: 1 kHz @ %3d dB SPL\n", L))
  cat(sprintf("  -> Total Loudness : %7.3f sones\n", res$Ldn))
  
  # Print the peak specific loudness
  idx <- which.min(abs(res$CF - 1000))
  cat(sprintf("  -> Peak specific  : %7.4f sones/Cam (at CF = %.1f Hz)\n\n", res$N_prime[idx], res$CF[idx]))
}


# Test 2: Hearing Impaired (50 dB OHC loss flat)
cat("--- TEST 2: Hearing Impaired (50 dB OHC flat) at 1 kHz ---\n")
HLohcdB0_HI <- rep(50, length(HLcf))
HLihcdB0_HI <- rep(0, length(HLcf))

for (L in levels) {
  inputF <- c(1000)
  inputLdB <- c(L)
  
  res <- calculate_loudness_cpp(inputF, inputLdB, HLcf, HLohcdB0_HI, HLihcdB0_HI)
  
  cat(sprintf("Input: 1 kHz @ %3d dB SPL\n", L))
  cat(sprintf("  -> Total Loudness : %7.3f sones\n", res$Ldn))
}

cat("\nVerification Complete. Values should monotonically increase and exhibit recruitment in Test 2.\n")
