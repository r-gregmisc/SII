source("R/sii.R")
source("R/moore_glasberg.R")
source("R/nalr.R")
source("R/open_nl.R")
source("R/plot.SII.R")
source("R/benchmark_targets.R")

d <- setup_data()
f_htl <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(15, 20, 30, 40, 50, 60)
loss_6 <- rep(0, 6)

target <- open_nl(speech = 65, threshold = threshold, freq = f_htl, loss = loss_6, optimize = TRUE)
print(target)
