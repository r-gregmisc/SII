library(devtools)
load_all()

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
a5 <- c(10, 10, 20, 60, 80, 100)
abg <- rep(0, 6)

# Let's see the default A5 loudness
tgt <- open_nl(65, threshold = a5, freq = freqs, loss = abg)
res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = a5, loss = abg, freq = freqs, prescription = NULL, method = "octave")
l1 <- calculate_loudness(res)
cat("Default A5 Loudness: ", l1, "\n")

# Now let's try replacing the logic in R/nalr.R
original_file <- readLines("R/nalr.R")
mod_file <- original_file
thresh <- 30
pen <- 15

mod_file <- gsub("if \\(slope_diff > 15\\) \\{", sprintf("if (slope_diff > %d) {", thresh), mod_file)
mod_file <- gsub("lf_penalty_factor <- pmin\\(1, \\(slope_diff - 15\\) / 20\\)", sprintf("lf_penalty_factor <- pmin(1, (slope_diff - %d) / 20)", thresh), mod_file)
mod_file <- gsub("lf_penalty_max <- lf_penalty_factor \\* 15 #", sprintf("lf_penalty_max <- lf_penalty_factor * %d #", pen), mod_file)

writeLines(mod_file, "R/nalr.R")
load_all(quiet=TRUE)

tgt <- open_nl(65, threshold = a5, freq = freqs, loss = abg)
res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = a5, loss = abg, freq = freqs, prescription = NULL, method = "octave")
l2 <- calculate_loudness(res)
cat("Modified A5 Loudness (thresh=30, pen=15): ", l2, "\n")

writeLines(original_file, "R/nalr.R")
load_all(quiet=TRUE)
