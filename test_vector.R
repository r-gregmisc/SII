source("R/moore_glasberg.R")

dense_f <- seq(20, 15000, by = 10)
dense_l <- rep(65, length(dense_f))
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ohc_loss <- c(0, 5, 10, 15, 20, 25)
ihc_loss <- c(0, 0, 5, 5, 10, 10)

cat("Running calculate_loudness_chen2011...\n")

t0 <- Sys.time()
res <- calculate_loudness_chen2011(inputF = dense_f, inputLdB = dense_l,
  HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss,
  cambin = 0.1, outerearcorrection = 'FreeField')
t1 <- Sys.time()

cat(sprintf("Time taken: %.3f seconds\n", as.numeric(difftime(t1, t0, units="secs"))))
cat(sprintf("Loudness: %.5f sones\n", res$total))

# Save expected output for comparison
if (!file.exists("expected_loudness.rds")) {
    saveRDS(res, "expected_loudness.rds")
    cat("Saved baseline to expected_loudness.rds\n")
} else {
    expected <- readRDS("expected_loudness.rds")
    diff_total <- abs(res$total - expected$total)
    diff_max <- max(abs(res$Ldn - expected$Ldn))
    cat(sprintf("Max Ldn diff: %.1e\n", diff_max))
    cat(sprintf("Total diff: %.1e\n", diff_total))
    if (diff_max < 1e-10) {
        cat("PASS: Numerically equivalent!\n")
    } else {
        cat("FAIL: Numerical differences detected!\n")
    }
}
