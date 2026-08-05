source("R/sii.R")
source("R/moore_glasberg.R")

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
t <- rep(50, 6)

res_un_sn <- sii(speech="normal", threshold=t, freq=freqs, method="octave")
l_un_sn <- calculate_loudness(res_un_sn)

res_un_cond <- sii(speech="normal", threshold=t, loss=t, freq=freqs, method="octave")
l_un_cond <- calculate_loudness(res_un_cond)

gain_nalnl2 <- c(14, 15, 17, 18, 18, 18)
res_nalnl2_cond <- sii(speech="normal", threshold=t, loss=t, custom_gain=gain_nalnl2, freq=freqs, method="octave")
l_nalnl2_cond <- calculate_loudness(res_nalnl2_cond)

cat(sprintf("Unaided (forgetting loss=): %.2f sones\n", l_un_sn))
cat(sprintf("Unaided (correct conductive): %.2f sones\n", l_un_cond))
cat(sprintf("NAL-NL2 (correct conductive): %.2f sones\n", l_nalnl2_cond))
