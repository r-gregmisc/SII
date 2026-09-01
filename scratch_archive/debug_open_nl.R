source("R/sii.R")
source("R/nalr.R")
Rcpp::sourceCpp("src/bramslow2004.cpp")

# A6 Thresholds and Loss from benchmark_targets.R
freqs <- c(125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000)
threshold <- c(50, 55, 60, 65, 75, 80)
loss <- c(30, 30, 30, 30, 30, 30)
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

source("R/open_nl.R")

cat("\n--- Running A6 ---\n")
res <- open_nl(speech = 65, threshold = threshold, freq = hl_freqs, loss = loss)
cat("A6 Gain: ", paste(round(res$gain, 2), collapse=", "), "\n")

cat("\n--- Running A7 ---\n")
threshold_A7 <- c(50, 50, 50, 50, 50, 50)
loss_A7 <- c(50, 50, 50, 50, 50, 50)
res2 <- open_nl(speech = 65, threshold = threshold_A7, freq = hl_freqs, loss = loss_A7)
cat("A7 Gain: ", paste(round(res2$gain, 2), collapse=", "), "\n")
