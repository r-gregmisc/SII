source("R/RcppExports.R")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
gain_array <- rep(37.5, 6)
local_loss <- rep(50, 6)
threshold <- rep(50, 6)

aided_spl <- ltass_65 + gain_array - local_loss

f_half <- seq(0, 15000, by = 0.5); f_half[1] <- 1
li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
li[f_half > hl_freqs[6]] <- aided_spl[6] - 24 * log2(f_half[f_half > hl_freqs[6]] / hl_freqs[6])
overall <- 10 * log10(sum(10^(li / 10)) * 0.5)

dense_f <- seq(10, 23990, length.out = 100)
dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
dense_l[dense_f > hl_freqs[6]] <- aided_spl[6] - 24 * log2(dense_f[dense_f > hl_freqs[6]] / hl_freqs[6])
current_spl <- 10 * log10(sum(10^(dense_l / 10) * 10))
dense_l <- dense_l + (overall - current_spl)

sn_htl <- pmax(threshold - local_loss, 0)
res <- calculate_loudness_cpp(
      inputF     = dense_f,
      inputLdB   = dense_l,
      HLcf       = hl_freqs,
      HLohcdB0   = sn_htl,
      HLihcdB0   = rep(0, 6),
      NoChan     = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0
)
cat(sprintf("overall: %.2f\n", overall))
cat(sprintf("current_spl: %.2f\n", current_spl))
cat(sprintf("Loudness: %.2f\n", res$Ldn))
