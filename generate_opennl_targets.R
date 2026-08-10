library(devtools)
load_all()
profiles = list(A1 = c(15, 20, 30, 40, 50, 60), A2 = c(60, 50, 40, 30, 20, 15), A3 = c(10, 20, 40, 50, 55, 60), A4 = c(0, 0, 10, 40, 70, 80), A5 = c(10, 10, 20, 60, 80, 100), A6 = c(50, 55, 60, 65, 75, 80), A7 = c(50, 50, 50, 50, 50, 50))
abg_list = list(A1 = rep(0, 6), A2 = rep(0, 6), A3 = rep(0, 6), A4 = rep(0, 6), A5 = rep(0, 6), A6 = c(30, 30, 30, 30, 30, 30), A7 = c(50, 50, 50, 50, 50, 50))
freqs = c(250, 500, 1000, 2000, 4000, 8000)
cat("Profile,F250,F500,F1000,F2000,F4000,F8000\n", file="opennl_targets_65.csv")
for (p in names(profiles)) {
  tgt = open_nl(65, threshold=profiles[[p]], freq=freqs, loss=abg_list[[p]])
  g65 = tgt$gain
  cat(sprintf("%s,%f,%f,%f,%f,%f,%f\n", p, g65[1], g65[2], g65[3], g65[4], g65[5]], g65[6]), file="opennl_targets_65.csv", append=TRUE)
}
cat("opennl_targets_65.csv generated.\n")
