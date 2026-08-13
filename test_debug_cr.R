# Debug WDRC test
for (f in c("R/sii.R", "R/moore_glasberg.R", "R/nalr.R", "R/plot.SII.R", "R/benchmark_targets.R", "R/open_nl.R")) {
  source(f, local = FALSE)
}

freq <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(15, 20, 30, 40, 50, 60)

target <- open_nl(speech = 65, threshold = threshold, freq = freq, 
                  loss = rep(0, 6), optimize = TRUE)

cat("Target speech stored:", round(target$speech, 1), "\n")
cat("Target gain stored:", round(target$gain, 1), "\n")
cat("Target freq stored:", target$freq, "\n\n")

data("critical", package = "SII")
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
htl_21 <- approx(x = log10(freq), y = threshold, xout = log10(critical$fi), rule = 2)$y

# Test at 50 dB
speech_50 <- critical$normal + (50 - overall_normal)
speech_65 <- critical$normal + (65 - overall_normal)

# What level_diff should be
speech_ref_interp <- approx(x = log10(target$freq), y = target$speech, 
                            xout = log10(critical$fi), rule = 2)$y
level_diff <- mean(speech_50 - speech_ref_interp, na.rm = TRUE)
cat("Computed level_diff (50 dB):", round(level_diff, 2), "\n")

level_diff_65 <- mean(speech_65 - speech_ref_interp, na.rm = TRUE)
cat("Computed level_diff (65 dB):", round(level_diff_65, 2), "\n")

# What CR_base should be
htl_sn <- pmax(0, threshold)
cr_base <- 1 + pmax(0, htl_sn - 20) / 40
cat("CR_base at 6 freqs:", round(cr_base, 2), "\n")

# What the gain adjustment should be for 50 dB
gain_adj <- level_diff * (1 / cr_base - 1)
cat("Gain adjustment (50 dB):", round(gain_adj, 1), "\n")
cat("Adjusted gain (50 dB):", round(target$gain + gain_adj, 1), "\n")
