source("R/sii.R")
source("R/moore_glasberg.R")
source("R/nalr.R")
source("R/open_nl.R")
source("R/benchmark_targets.R")

profiles <- list(
  A1 = list(threshold = c(15, 20, 30, 40, 50, 60), loss = rep(0, 6)),
  A2 = list(threshold = c(60, 50, 40, 30, 20, 15), loss = rep(0, 6)),
  A3 = list(threshold = c(10, 20, 40, 50, 55, 60), loss = rep(0, 6)),
  A4 = list(threshold = c(0, 0, 10, 40, 70, 80),   loss = rep(0, 6)),
  A5 = list(threshold = c(10, 10, 20, 60, 80, 100), loss = rep(0, 6)),
  A6 = list(threshold = c(50, 55, 60, 65, 75, 80),  loss = c(30, 30, 30, 30, 30, 30)),
  A7 = list(threshold = c(50, 50, 50, 50, 50, 50),  loss = c(50, 50, 50, 50, 50, 50))
)

freq <- c(250, 500, 1000, 2000, 4000, 8000)

cat("\n=== New Table II Insertion Gains ===\n\n")
for (i in 1:7) {
  name <- paste0("A", i)
  p <- profiles[[name]]
  
  target <- open_nl(speech = 65, threshold = p$threshold, freq = freq, 
                    loss = p$loss, optimize = TRUE)
  
  cat(sprintf("| | Open-NL | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n", 
      target$gain[1], target$gain[2], target$gain[3], target$gain[4], target$gain[5], target$gain[6]))
}
