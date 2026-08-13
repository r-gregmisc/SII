# Test WDRC compression ratios
for (f in c("R/sii.R", "R/moore_glasberg.R", "R/nalr.R", "R/plot.SII.R", "R/benchmark_targets.R", "R/open_nl.R")) {
  source(f, local = FALSE)
}

freq <- c(250, 500, 1000, 2000, 4000, 8000)

# Test with A1 (mild sloping: 15, 20, 30, 40, 50, 60)
threshold <- c(15, 20, 30, 40, 50, 60)

target <- open_nl(speech = 65, threshold = threshold, freq = freq, 
                  loss = rep(0, 6), optimize = TRUE)

cat("Open-NL gains at 65 dB (anchor):", round(target$gain, 1), "\n\n")

# Load critical band data
data("critical", package = "SII")
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))

# Compute SII at 50, 65, 80 dB
htl_21 <- approx(x = log10(freq), y = threshold, xout = log10(critical$fi), rule = 2)$y

for (level in c(50, 65, 80)) {
  speech_spec <- critical$normal + (level - overall_normal)
  obj <- sii(speech = speech_spec, threshold = htl_21,
             freq = critical$fi, prescription = target, 
             desensitization = FALSE, interpolate = FALSE)
  
  ig <- pmax(0, obj$table[, "E'i"] - obj$unaided_speech)
  ig_octaves <- approx(x = log10(critical$fi), y = ig, xout = log10(freq), rule = 2)$y
  cat(sprintf("Gains at %d dB: %s\n", level, paste(round(ig_octaves, 1), collapse = "  ")))
}

# Compute compression ratios
speech_50 <- critical$normal + (50 - overall_normal)
speech_80 <- critical$normal + (80 - overall_normal)
obj50 <- sii(speech = speech_50, threshold = htl_21, freq = critical$fi, 
             prescription = target, desensitization = FALSE, interpolate = FALSE)
obj80 <- sii(speech = speech_80, threshold = htl_21, freq = critical$fi, 
             prescription = target, desensitization = FALSE, interpolate = FALSE)

g50 <- pmax(0, obj50$table[, "E'i"] - obj50$unaided_speech)
g80 <- pmax(0, obj80$table[, "E'i"] - obj80$unaided_speech)

g50_oct <- approx(x = log10(critical$fi), y = g50, xout = log10(freq), rule = 2)$y
g80_oct <- approx(x = log10(critical$fi), y = g80, xout = log10(freq), rule = 2)$y

delta_out <- 30 + g80_oct - g50_oct
cr <- 30 / pmax(delta_out, 0.01)
cat(sprintf("\nCompression Ratios: %s\n", paste(round(cr, 2), collapse = "  ")))

# Also show expected CR_base from formula
htl_sn <- pmax(0, threshold)
cr_expected <- 1 + pmax(0, htl_sn - 20) / 40
cat(sprintf("Expected CR_base:   %s\n", paste(round(cr_expected, 2), collapse = "  ")))
