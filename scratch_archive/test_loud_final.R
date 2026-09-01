source("R/benchmark_targets.R")
source("R/moore_glasberg.R")
source("R/open_nl.R")

calc_amt_loudness <- function(gain_tgt, htl, cond, target_level, bin) {
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78) + (target_level - 65)
  aided_spl <- input_speech + gain_tgt - cond
  f_half <- seq(0, 24000, by = 0.5)
  f_half[1] <- 1
  levels_interp <- approx(x = log10(freqs), y = aided_spl, xout = log10(f_half), rule = 2)$y
  idx_low <- which(f_half < freqs[1])
  if (length(idx_low) > 0) levels_interp[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / pmax(f_half[idx_low], 1))
  idx_high <- which(f_half > freqs[length(freqs)])
  if (length(idx_high) > 0) levels_interp[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[idx_high] / freqs[length(freqs)])
  overall <- 10 * log10(sum(10^(levels_interp/10)) * 0.5)
  
  dense_f <- seq(1, 24000, by = 5)
  dense_l <- approx(x = log10(freqs), y = aided_spl, xout = log10(dense_f), rule = 2)$y
  idx_low <- which(dense_f < freqs[1])
  if (length(idx_low) > 0) dense_l[idx_low] <- aided_spl[1] - 24 * log2(freqs[1] / dense_f[idx_low])
  idx_high <- which(dense_f > freqs[length(freqs)])
  if (length(idx_high) > 0) dense_l[idx_high] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[idx_high] / freqs[length(freqs)])
  
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 5))
  offset <- overall - current_spl
  dense_l <- dense_l + offset
  
  sn_loss <- htl - cond
  ohc <- sn_loss
  ihc <- rep(0, length(sn_loss))
  
  loudness_res <- calculate_loudness_cpp(
    inputF = dense_f, 
    inputLdB = dense_l, 
    HLcf = freqs, 
    HLohcdB0 = ohc, 
    HLihcdB0 = ihc,
    Binaural = bin
  )
  return(loudness_res$Ldn)
}

p <- "a1"
loss <- jd2011_targets[[p]]$threshold
cond <- rep(0, 6)

# Generate Open-NL target
res <- open_nl(speech = 65, threshold = loss, freq = c(250, 500, 1000, 2000, 4000, 8000), loss = cond)

cat(sprintf("Open-NL A1 Monaural (Binaural=0): %.2f\n", calc_amt_loudness(res$gain, loss, cond, 65, 0)))
cat(sprintf("Open-NL A1 Binaural (Binaural=1): %.2f\n", calc_amt_loudness(res$gain, loss, cond, 65, 1)))

