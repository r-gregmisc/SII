library(SII)
source("R/sii.R")
source("R/nalr.R")
source("R/open_nl.R")

htl <- c(15, 20, 30, 40, 50, 60)
cond <- rep(0, 6)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)

cat("\n--- RUNNING OPEN-NL OPTIMIZER WITH COUPLING=OPEN ---\n")
opennl_res <- open_nl(speech=65, threshold=htl, loss=cond, freq=freqs, config="bilateral", coupling="open")
cat("Optimized Gain:", round(opennl_res$gain, 2), "\n")
