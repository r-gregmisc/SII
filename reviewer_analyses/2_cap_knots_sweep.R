library(SII)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)
threshold_A5 <- c(70, 75, 80, 85, 90, 95)
for (shift in c(-2, 0, 2, 4, 6)) {
  tgt <- suppressMessages(open_nl(speech = 65, threshold = threshold_A5, freq = freqs, cap_shift = shift, seed_noise=10))
  cat(sprintf("Shift: %+4.1f Sones | High-Freq Gain (4kHz): %4.1f dB\n", shift, tgt$gain[5]))
}
