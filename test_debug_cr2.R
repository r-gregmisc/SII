# Direct debug: trace inside sii()
for (f in c("R/sii.R", "R/moore_glasberg.R", "R/nalr.R", "R/plot.SII.R", "R/benchmark_targets.R", "R/open_nl.R")) {
  source(f, local = FALSE)
}

freq <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(15, 20, 30, 40, 50, 60)

target <- open_nl(speech = 65, threshold = threshold, freq = freq, 
                  loss = rep(0, 6), optimize = TRUE)

data("critical", package = "SII")
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
htl_21 <- approx(x = log10(freq), y = threshold, xout = log10(critical$fi), rule = 2)$y

# Call sii at 50 dB and manually trace
speech_50 <- critical$normal + (50 - overall_normal)

# Check: does inherits work?
cat("Is prescription_target?", inherits(target, "prescription_target"), "\n")
cat("Class:", class(target), "\n")

# Manually replicate what sii() does for prescription_target
presc <- target
eval_freq <- critical$fi

# Interpolate gain
gain_65 <- approx(x = log10(presc$freq), y = presc$gain, xout = log10(eval_freq), rule = 2)$y
cat("\ngain_65 (21 bands, first 5):", round(gain_65[1:5], 2), "\n")

# WDRC
p_loss <- if (!is.null(presc$loss)) presc$loss else rep(0, length(presc$freq))
p_threshold <- if (!is.null(presc$threshold)) presc$threshold else htl_21

htl_sn_interp <- approx(x = log10(presc$freq), y = p_threshold, xout = log10(eval_freq), rule = 2)$y
loss_interp <- approx(x = log10(presc$freq), y = p_loss, xout = log10(eval_freq), rule = 2)$y
htl_sn <- pmax(0, htl_sn_interp - loss_interp)

cr_base <- 1 + pmax(0, htl_sn - 20) / 40
cat("cr_base (21 bands, first 5):", round(cr_base[1:5], 2), "\n")

speech_ref <- approx(x = log10(presc$freq), y = presc$speech, xout = log10(eval_freq), rule = 2)$y
level_diff <- mean(speech_50 - speech_ref, na.rm = TRUE)
cat("level_diff:", round(level_diff, 2), "\n")
cat("abs(level_diff) > 1?", abs(level_diff) > 1, "\n")

gain_wdrc <- gain_65 + level_diff * (1 / cr_base - 1)
gain_wdrc <- pmax(0, gain_wdrc)
cat("\nGain at 65 dB (interp to octaves):", round(approx(log10(eval_freq), gain_65, xout=log10(freq), rule=2)$y, 1), "\n")
cat("Gain at 50 dB WDRC (interp to octaves):", round(approx(log10(eval_freq), gain_wdrc, xout=log10(freq), rule=2)$y, 1), "\n")

# Now actually call sii and check the result
obj <- sii(speech = speech_50, threshold = htl_21, freq = eval_freq,
           prescription = target, desensitization = FALSE, interpolate = FALSE)
cat("\nActual E'i from sii() (first 5):", round(obj$table[1:5, "E'i"], 2), "\n")
cat("Actual unaided_speech (first 5):", round(obj$unaided_speech[1:5], 2), "\n")
cat("Actual gain = E'i - unaided (first 5):", round(obj$table[1:5, "E'i"] - obj$unaided_speech[1:5], 2), "\n")
cat("Expected gain_wdrc (first 5):", round(gain_wdrc[1:5], 2), "\n")
