library(SII)
source("R/benchmark_targets.R")
source("R/open_nl.R")

p_keys <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
p_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

for (i in 1:length(p_keys)) {
  p <- p_keys[i]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- jd2011_targets[[p]]$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  res <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss)
  op_tgt <- res$gain
  
  cat(sprintf("Profile %s Open-NL Gain: %.1f %.1f %.1f %.1f %.1f %.1f\n", 
              p_names[i], op_tgt[1], op_tgt[2], op_tgt[3], op_tgt[4], op_tgt[5], op_tgt[6]))
}
