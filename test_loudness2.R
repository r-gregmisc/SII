library(devtools)
load_all(quiet=TRUE)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
a5 <- c(10, 10, 20, 60, 80, 100)
abg <- rep(0, 6)

tgt <- open_nl(65, threshold = a5, freq = freqs, loss = abg)
res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = a5, loss = abg, freq = freqs, prescription = NULL, method = "octave")
l1 <- calculate_loudness(res)
cat("A5 Default: ", l1, "\n")

original_file <- readLines("R/nalr.R")
mod_file <- gsub("g_base <- g_base \\+ 0\\.15 \\* pmax\\(0, sn_threshold - 60\\)", 
                 "g_base <- g_base + 0.0 * pmax(0, sn_threshold - 60)", 
                 original_file)
writeLines(mod_file, "R/nalr.R")
suppressMessages(load_all(".", quiet=TRUE))

tgt <- open_nl(65, threshold = a5, freq = freqs, loss = abg)
res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = a5, loss = abg, freq = freqs, prescription = NULL, method = "octave")
l2 <- calculate_loudness(res)
cat("A5 (booster disabled): ", l2, "\n")

writeLines(original_file, "R/nalr.R")
