source("R/benchmark_targets.R")
source("data_output/generate_open_nl_metrics.R")

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
cat("NAL-NL2 A7 gain:\n")
nal_gain  <- get_jd2011_target("a7", "NAL-NL2", hl_freqs, 65)
print(nal_gain)

cat("Open-NL A7 gain:\n")
op_res   <- open_nl(speech = 65, threshold = rep(50,6), freq = hl_freqs, loss = rep(50,6))
print(op_res$gain)
