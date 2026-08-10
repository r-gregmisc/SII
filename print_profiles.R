profiles = list(
  A1 = c(15, 20, 30, 40, 50, 60),
  A2 = c(60, 50, 40, 30, 20, 15),
  A3 = c(10, 20, 40, 50, 55, 60),
  A4 = c(0, 0, 10, 40, 70, 80),
  A5 = c(10, 10, 20, 60, 80, 100),
  A6 = c(50, 55, 60, 65, 75, 80),
  A7 = c(50, 50, 50, 50, 50, 50)
)
for (p in names(profiles)) {
  lf = mean(profiles[[p]][1:3])
  hf = mean(profiles[[p]][4:6])
  cat(sprintf("%s: LF=%.1f, HF=%.1f, Slope=%.1f\n", p, lf, hf, hf-lf))
}
