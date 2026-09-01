library(SII)

# Inject print into open_nl.R safely
lines <- readLines("R/open_nl.R")
idx <- grep("return\\(-score \\+ anchor_penalty \\+ loudness_penalty \\+ out_of_bounds_penalty \\+ spl_penalty\\)", lines)
if (length(idx) > 0) {
  lines[idx] <- "cat(sprintf('SHIFTS: %s | SII: %.2f | LOUD: %.2f | PEN: %.1f\\n', paste(round(shifts,1), collapse=','), score, loudness_sones, loudness_penalty))\n      return(-score + anchor_penalty + loudness_penalty + out_of_bounds_penalty + spl_penalty)"
  writeLines(lines, "R/open_nl_debug.R")
  cat("Debug injected successfully!\n")
} else {
  cat("Failed to inject debug print. Using original open_nl.R.\n")
  file.copy("R/open_nl.R", "R/open_nl_debug.R", overwrite=TRUE)
}

source("R/sii.R")
source("R/nalr.R")
source("R/open_nl_debug.R")

cat("\n--- RUNNING DEBUG ---\n")
htl <- c(15, 20, 30, 40, 50, 60)
cond <- rep(0, 6)
res <- open_nl(speech=65, threshold=htl, loss=cond, freq=c(250, 500, 1000, 2000, 4000, 8000), config="bilateral")
cat("FINAL GAIN:", res$target$gain, "\n")
