library(devtools)
suppressMessages(load_all(".", quiet=TRUE))

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
a5 <- c(10, 10, 20, 60, 80, 100)
abg <- rep(0, 6)

original_file <- readLines("R/nalr.R")

for (thresh in c(10, 80)) {
  for (pen in c(0, 30)) {
    mod_file <- original_file
    mod_file <- gsub("if \\(slope_diff > 15\\) \\{", sprintf("if (slope_diff > %d) {", thresh), mod_file)
    mod_file <- gsub("lf_penalty_factor <- pmin\\(1, \\(slope_diff - 15\\) / 20\\)", sprintf("lf_penalty_factor <- pmin(1, (slope_diff - %d) / 20)", thresh), mod_file)
    mod_file <- gsub("lf_penalty_max <- lf_penalty_factor \\* 15 #", sprintf("lf_penalty_max <- lf_penalty_factor * %d #", pen), mod_file)
    writeLines(mod_file, "R/nalr.R")
    source("R/nalr.R")
    
    tgt <- open_nl(65, threshold = a5, freq = freqs, loss = abg)
    res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = a5, loss = abg, freq = freqs, prescription = NULL, method = "octave")
    ldn <- calculate_loudness(res)
    cat(sprintf("thresh=%d, pen=%d, sones=%f\n", thresh, pen, ldn))
  }
}
writeLines(original_file, "R/nalr.R")
