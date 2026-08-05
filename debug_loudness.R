# Debug script: check loudness model values for A-1 audiogram
# Run from R console: source("debug_loudness.R")

library(SII)
source("R/sii.R")
source("R/moore_glasberg.R")
source("R/nalr.R")
source("R/benchmark_targets.R")

# A-1 audiogram (mild-to-moderate sloping)
htl <- c(20, 30, 45, 60, 75, 80)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)

# Get DSL v5.0 targets at 65 dB input
targets <- get_benchmark_targets(htl, freqs)
dsl_gain <- targets$dsl

cat("\n=== A-1 Audiogram ===\n")
cat("HTL:", htl, "\n")
cat("DSL gain:", round(dsl_gain, 1), "\n")

# Run SII with DSL gain
obj <- sii(speech = "normal", threshold = htl, freq = freqs, 
           custom_gain = dsl_gain, method = "critical")

cat("\n=== SII Table (key columns) ===\n")
cat("Freq (Fi):", obj$table$Fi, "\n")
cat("E'i (aided speech spectrum level):", round(obj$table$"E'i", 1), "\n")
cat("T'i (threshold):", round(obj$table$"T'i", 1), "\n")

# Check what values go into the loudness model
aided_density <- obj$table$"E'i"
cat("\n=== Loudness Model Input ===\n")
cat("Min E'i:", min(aided_density), "dB/Hz\n")
cat("Max E'i:", max(aided_density), "dB/Hz\n")
cat("Mean E'i:", mean(aided_density), "dB/Hz\n")

# Calculate loudness
loudness <- calculate_loudness(obj)
cat("\nCalculated loudness:", round(loudness, 2), "sones\n")

# Also test normal hearing at 65 dB (no gain, no loss)
obj_nh <- sii(speech = "normal", threshold = rep(0, 6), freq = freqs, method = "critical")
loudness_nh <- calculate_loudness(obj_nh)
cat("Normal hearing loudness (65 dB, no aid):", round(loudness_nh, 2), "sones\n")
cat("Expected: ~8-12 sones monaural\n")
