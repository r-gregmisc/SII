library(SII)
source("R/open_nl.R")
source("R/benchmark_targets.R")

# Inject a print statement into open_nl.R to watch the optimizer think
lines <- readLines("R/open_nl.R")
idx <- grep("return\\(-score \\+ loudness_penalty \\+ out_of_bounds_penalty\\)", lines)
lines[idx] <- "cat(sprintf('SHIFTS: %s | SII: %.2f | LOUDNESS: %.2f | PENALTY: %.1f | OBJ: %.1f\\n', paste(round(shifts,1), collapse=','), score, loudness_sones, loudness_penalty, -score + loudness_penalty + out_of_bounds_penalty))\n      return(-score + loudness_penalty + out_of_bounds_penalty)"
writeLines(lines, "R/open_nl_debug.R")

# Overwrite it with the debug version
source("R/open_nl_debug.R")

cat("\n--- RUNNING OPEN-NL OPTIMIZER FOR A1 ---\n")
htl <- c(15, 20, 30, 40, 50, 60)
cond <- rep(0, 6)
res <- open_nl(speech=65, threshold=htl, loss=cond, freq=c(250, 500, 1000, 2000, 4000, 8000), config="bilateral")
cat("FINAL GAIN:", round(res$target$gain, 2), "\n")
