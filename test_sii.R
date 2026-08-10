library(devtools)
load_all(quiet=TRUE)
a5 <- c(10, 10, 20, 60, 80, 100)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)
abg <- rep(0, 6)

original_file <- readLines("R/nalr.R")

# WITH SD-LFP
tgt_full <- open_nl(65, threshold = a5, freq = freqs, loss = abg)
sii_full <- sii(speech = tgt_full$speech + tgt_full$gain, noise = rep(-100, 6), threshold = a5, loss = abg, freq = freqs, prescription = NULL, method = "octave")
l_full <- calculate_loudness(sii_full)
cat("Full Model: SII=", sii_full$sii, " Loudness=", l_full, "\n")
cat("Full Model Gain:", tgt_full$gain, "\n")

# WITHOUT SD-LFP
mod_file <- original_file
mod_file <- gsub("if \\(slope_diff > 15\\) \\{", "if (FALSE) {", mod_file)
writeLines(mod_file, "R/nalr.R")
suppressMessages(load_all(".", quiet=TRUE))

tgt_no_sdlfp <- open_nl(65, threshold = a5, freq = freqs, loss = abg)
sii_no_sdlfp <- sii(speech = tgt_no_sdlfp$speech + tgt_no_sdlfp$gain, noise = rep(-100, 6), threshold = a5, loss = abg, freq = freqs, prescription = NULL, method = "octave")
l_no_sdlfp <- calculate_loudness(sii_no_sdlfp)
cat("No SD-LFP: SII=", sii_no_sdlfp$sii, " Loudness=", l_no_sdlfp, "\n")
cat("No SD-LFP Gain:", tgt_no_sdlfp$gain, "\n")

writeLines(original_file, "R/nalr.R")
