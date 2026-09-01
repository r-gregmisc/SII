source("R/open_nl.R")
source("R/benchmark_targets.R")

htl <- c(15, 20, 30, 40, 50, 60)
cond <- rep(0, 6)

cat("Running open_nl for A1...\n")
res <- open_nl(speech=65, threshold=htl, loss=cond, freq=c(250, 500, 1000, 2000, 4000, 8000), config="bilateral")
cat("Open-NL Gain:", res$target$gain, "\n")
