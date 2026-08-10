source("R/sii.R")
source("R/nalr.R")
source("R/open_nl.R")
source("R/moore_glasberg.R")

freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)

a1 <- c(10, 10, 10, 15, 30, 40, 50, 50)
a2 <- c(35, 35, 30, 20, 15, 10, 10, 10)
a3 <- c(10, 15, 30, 45, 55, 60, 65, 65)
a4 <- c(15, 25, 40, 75, 80, 80, 80, 80)
a5 <- c(20, 30, 45, 85, 95, 100, 100, 100)
a6 <- c(35, 45, 60, 75, 80, 80, 80, 80)
a7 <- c(35, 35, 35, 35, 35, 35, 35, 35)

profiles <- list(a1, a2, a3, a4, a5, a6, a7)
names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")
losses <- list(rep(0,8), rep(0,8), rep(0,8), rep(0,8), rep(0,8), c(15,15,15,15,15,15,15,15), rep(35,8))

for (i in 1:length(profiles)) {
  thresh <- profiles[[i]]
  loss <- losses[[i]]
  
  prescription <- open_nl(speech = 65, threshold = thresh, loss = loss, freq = freqs, optimize = TRUE)
  
  res <- sii(speech = 65, noise = rep(-50, length(freqs)), threshold = thresh, loss = loss, freq = freqs, prescription = prescription, interpolate=TRUE, desensitization=TRUE)
  loud <- calculate_loudness(res)$total
  
  cat(names[i], "- SII:", round(res$sii, 2), "Loudness:", round(loud, 1), "\n")
}
