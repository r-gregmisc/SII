source("R/sii.R")
source("R/open_nl.R")
source("R/moore_glasberg.R")

presets <- list(
  a1 = list(threshold = c(15, 20, 30, 40, 50, 60), loss = rep(0, 6), gain = c(4, 5, 12, 19, 21, 15)),
  a2 = list(threshold = c(60, 50, 40, 30, 20, 15), loss = rep(0, 6), gain = c(20, 16, 12, 6, 2, 2)),
  a3 = list(threshold = c(10, 20, 40, 50, 55, 60), loss = rep(0, 6), gain = c(6, 16, 22, 22, 16, 6)),
  a4 = list(threshold = c(0, 0, 10, 40, 70, 80), loss = rep(0, 6), gain = c(0, 0, 0, 16, 31, 30)),
  a5 = list(threshold = c(10, 10, 20, 60, 80, 100), loss = rep(0, 6), gain = c(0, 0, 15, 28, 30, 30))
)

cat("Profile\tCalculated\tJ&D 2011\n")
cat("----------------------------------\n")

jd_vals <- c(a1=7.4, a2=5.8, a3=8.1, a4=11.9, a5=11.1)
f_htl <- c(250, 500, 1000, 2000, 4000, 8000)

for (p in names(presets)) {
  # Calculate custom gain target object
  targ <- structure(list(freq = f_htl, gain = presets[[p]]$gain, mpo = rep(120, 6)), class="prescription_target")
  
  res <- sii(speech = 65, noise = 0, threshold = presets[[p]]$threshold, loss = presets[[p]]$loss, freq = f_htl, method = "critical", prescription = targ)
  l_uni <- calculate_loudness(res)
  cat(sprintf("%s\t%.1f\t\t%.1f\n", p, l_uni, jd_vals[[p]]))
}
