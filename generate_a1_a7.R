library(devtools)
load_all()

profiles = list(
  A1 = c(15, 20, 30, 40, 50, 60),
  A2 = c(60, 50, 40, 30, 20, 15),
  A3 = c(10, 20, 40, 50, 55, 60),
  A4 = c(0, 0, 10, 40, 70, 80),
  A5 = c(10, 10, 20, 60, 80, 100),
  A6 = c(50, 55, 60, 65, 75, 80),
  A7 = c(50, 50, 50, 50, 50, 50)
)
abg_list = list(
  A1 = rep(0, 6),
  A2 = rep(0, 6),
  A3 = rep(0, 6),
  A4 = rep(0, 6),
  A5 = rep(0, 6),
  A6 = c(30, 30, 30, 30, 30, 30),
  A7 = c(50, 50, 50, 50, 50, 50)
)
freqs = c(250, 500, 1000, 2000, 4000, 8000)

results <- data.frame(Profile=character(), R_Sones=numeric(), stringsAsFactors=FALSE)

for (p in names(profiles)) {
  sn_htl <- profiles[[p]]
  abg <- abg_list[[p]]
  
  # Calculate open_nl targets
  tgt <- open_nl(65, threshold=sn_htl, freq=freqs, loss=abg)
  
  res <- sii(speech=tgt$speech + tgt$gain, noise=rep(-100,6), threshold=sn_htl, freq=freqs, loss=abg, prescription=NULL, method="octave")
  
  # Calculate loudness in R (this calls calculate_loudness_chen2011 internally)
  l <- calculate_loudness(res)
  
  # Reconstruct the exact dense spectrum that calculate_loudness used
  aided_density <- res$table$"E'i"
  dense_f <- seq(20, 15000, by=1)
  dense_l <- rep(-100, length(dense_f))
  dense_l <- approx(x = log10(freqs), y = aided_density, xout = log10(dense_f), rule=1)$y
  
  idx_low <- which(dense_f < freqs[1])
  if (length(idx_low) > 0) {
    octaves_below <- log2(freqs[1] / dense_f[idx_low])
    dense_l[idx_low] <- aided_density[1] - 24 * octaves_below
  }
  
  last_freq <- freqs[length(freqs)]
  idx_high <- which(dense_f > last_freq)
  if (length(idx_high) > 0) {
    octaves_above <- log2(dense_f[idx_high] / last_freq)
    dense_l[idx_high] <- aided_density[length(aided_density)] - 24 * octaves_above
  }
  
  dense_l[is.na(dense_l)] <- -100
  
  dense_abg <- approx(x = log10(freqs), y = abg, xout = log10(dense_f), rule=2)$y
  dense_l <- dense_l - dense_abg
  
  dense_spec <- data.frame(f=dense_f, l_density=dense_l)
  write.csv(dense_spec, sprintf("spec_%s.csv", p), row.names=FALSE)
  
  results <- rbind(results, data.frame(Profile=p, R_Sones=l))
}

write.csv(results, "r_sones_a1_a7.csv", row.names=FALSE)
cat("R export complete.\n")
