library(SII)
source("R/benchmark_targets.R")

# Inject print into open_nl.R
lines <- readLines("R/open_nl.R")
idx <- grep("return\\(-score \\+ loudness_penalty \\+ out_of_bounds_penalty\\)", lines)
lines[idx] <- "cat(sprintf('SHIFTS: %s | SII: %.2f | LOUDNESS: %.2f | PENALTY: %.1f | OBJ: %.1f\\n', paste(round(shifts,1), collapse=','), score, loudness_sones, loudness_penalty, -score + loudness_penalty + out_of_bounds_penalty))\n      return(-score + loudness_penalty + out_of_bounds_penalty)"
writeLines(lines, "R/open_nl_debug.R")

# Load ALL internal files so it can find calculate_open_nl_gain
source("R/sii.R")
source("R/nalr.R")
source("R/open_nl_debug.R")

cat("\n--- RUNNING DEBUG ---\n")
htl <- c(15, 20, 30, 40, 50, 60)
cond <- rep(0, 6)
res <- open_nl(speech=65, threshold=htl, loss=cond, freq=c(250, 500, 1000, 2000, 4000, 8000), config="bilateral")
