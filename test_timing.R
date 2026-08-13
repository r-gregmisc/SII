# Quick timing test: one profile with full-res Chen 2011 in optimizer
for (f in c("R/sii.R", "R/moore_glasberg.R", "R/nalr.R", "R/plot.SII.R", "R/benchmark_targets.R", "R/open_nl.R")) {
  source(f, local = FALSE)
}

freq <- c(250, 500, 1000, 2000, 4000, 8000)

# Test with A4 (worst case: severe HF loss, loudness penalty active)
cat("Testing A4 with coarse grid (current)...\n")
t1 <- system.time({
  target_coarse <- open_nl(speech = 65, 
    threshold = c(0, 0, 10, 40, 70, 80), 
    freq = freq, loss = rep(0, 6), optimize = TRUE)
})
cat("Coarse grid time:", t1[3], "seconds\n\n")

# Now temporarily modify to use full resolution (1 Hz spacing)
# We'll create a modified version inline
open_nl_fullres <- open_nl  # copy function
body_text <- deparse(body(open_nl_fullres))
body_text <- gsub("seq\\(20, 15000, by = 10\\)", "seq(20, 15000, by = 1)", body_text)
body(open_nl_fullres) <- parse(text = paste(body_text, collapse = "\n"))

cat("Testing A4 with full resolution (1 Hz)...\n")
t2 <- system.time({
  target_full <- open_nl_fullres(speech = 65, 
    threshold = c(0, 0, 10, 40, 70, 80), 
    freq = freq, loss = rep(0, 6), optimize = TRUE)
})
cat("Full resolution time:", t2[3], "seconds\n\n")

cat("Gain comparison (coarse vs full):\n")
cat(sprintf("  Freq: %s\n", paste(freq, collapse = "  ")))
cat(sprintf("  Coarse: %s\n", paste(sprintf("%.1f", target_coarse$gain), collapse = "  ")))
cat(sprintf("  Full:   %s\n", paste(sprintf("%.1f", target_full$gain), collapse = "  ")))
