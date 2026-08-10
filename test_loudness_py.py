import rpy2.robjects as ro
ro.r('''
library(devtools)
load_all()
a_profiles <- list(
  A1 = c(10, 10, 15, 25, 45, 55, 65, 70),
  A2 = c(20, 20, 25, 35, 45, 50, 50, 50),
  A3 = c(30, 35, 40, 45, 55, 60, 65, 70),
  A4 = c(50, 50, 55, 65, 70, 75, 80, 80),
  A5 = c(60, 65, 70, 75, 85, 90, 95, 95),
  A6 = c(25, 30, 35, 40, 50, 55, 60, 65),
  A7 = c(10, 10, 15, 25, 45, 55, 65, 70)
)
losses <- list(
  A1 = rep(0, 8), A2 = rep(0, 8), A3 = rep(0, 8), A4 = rep(0, 8), A5 = rep(0, 8),
  A6 = c(15, 15, 15, 15, 15, 15, 15, 15), 
  A7 = c(10, 10, 15, 25, 45, 55, 65, 70) 
)
freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)

for (p in names(a_profiles)) {
  s <- sii(speech = 65, threshold = a_profiles[[p]], loss = losses[[p]], freq = freqs, prescription = "Open-NL", experience = "experienced")
  l <- calculate_loudness(s)
  cat(sprintf("%s: Loudness = %.2f sones\n", p, l))
}
''')
