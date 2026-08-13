# Test Open-NL A1-A7 against manuscript Table I
# Source the R files directly
for (f in c("R/sii.R", "R/moore_glasberg.R", "R/nalr.R", "R/plot.SII.R", "R/benchmark_targets.R", "R/open_nl.R")) {
  source(f, local = FALSE)
}

profiles <- list(
  A1 = list(threshold = c(15, 20, 30, 40, 50, 60), loss = rep(0, 6)),
  A2 = list(threshold = c(60, 50, 40, 30, 20, 15), loss = rep(0, 6)),
  A3 = list(threshold = c(10, 20, 40, 50, 55, 60), loss = rep(0, 6)),
  A4 = list(threshold = c(0, 0, 10, 40, 70, 80),   loss = rep(0, 6)),
  A5 = list(threshold = c(10, 10, 20, 60, 80, 100), loss = rep(0, 6)),
  A6 = list(threshold = c(50, 55, 60, 65, 75, 80),  loss = c(30, 30, 30, 30, 30, 30)),
  A7 = list(threshold = c(50, 50, 50, 50, 50, 50),  loss = c(50, 50, 50, 50, 50, 50))
)

freq <- c(250, 500, 1000, 2000, 4000, 8000)

# Manuscript Table I values for Open-NL
manuscript <- data.frame(
  Profile = paste0("A", 1:7),
  SII_ms = c(0.86, 0.89, 0.82, 0.81, 0.72, 0.84, 0.95),
  Loudness_ms = c(9.4, 4.9, 9.0, 15.9, 11.0, 4.9, 12.0)
)

cat("\n=== Open-NL vs Manuscript Table I (65 dB SPL, Monaural) ===\n\n")
cat(sprintf("%-8s | %-10s %-10s %-10s | %-12s %-12s %-12s\n", 
    "Profile", "SII(ms)", "SII(app)", "Δ SII", "Loud(ms)", "Loud(app)", "Δ Loud"))
cat(paste(rep("-", 85), collapse=""), "\n")

for (i in 1:7) {
  name <- paste0("A", i)
  p <- profiles[[name]]
  
  # Run open_nl with optimize = TRUE (same as manuscript)
  target <- open_nl(speech = 65, threshold = p$threshold, freq = freq, 
                    loss = p$loss, optimize = TRUE)
  
  # Load critical band data for speech spectrum
  data("critical", package = "SII")
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_input <- critical$normal + (65 - overall_normal)
  
  # Interpolate threshold and loss to 21 bands
  htl_21 <- approx(x = log10(freq), y = p$threshold, xout = log10(critical$fi), rule = 2)$y
  loss_21 <- approx(x = log10(freq), y = p$loss, xout = log10(critical$fi), rule = 2)$y
  
  # Compute SII
  obj <- sii(speech = speech_input, threshold = htl_21, loss = loss_21,
             freq = critical$fi, prescription = target, 
             desensitization = FALSE, interpolate = FALSE)
  
  # Compute monaural loudness (full-resolution Chen 2011)
  loud <- calculate_loudness(obj)
  loudness_val <- loud$total
  
  ms <- manuscript[i, ]
  delta_sii <- obj$sii - ms$SII_ms
  delta_loud <- loudness_val - ms$Loudness_ms
  
  cat(sprintf("%-8s | %-10.3f %-10.3f %-+10.3f | %-12.1f %-12.1f %-+12.1f\n",
      name, ms$SII_ms, obj$sii, delta_sii, ms$Loudness_ms, loudness_val, delta_loud))
}

cat("\n")
