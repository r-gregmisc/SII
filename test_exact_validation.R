library(devtools)
load_all()
source("R/benchmark_targets.R")

A5_HL = c(10, 10, 20, 60, 80, 100)
A5_ABG = c(0, 0, 0, 0, 0, 0)
freqs = c(250, 500, 1000, 2000, 4000, 8000)

tgt_gain <- get_jd2011_target("a5", "CAMEQ2-HF", target_freqs = freqs, level = 65)
tgt <- sii(speech = "normal", threshold = A5_HL, loss = A5_ABG, freq = freqs, method = "octave", custom_gain = tgt_gain)

# Get exact internal vectors
aided_density = tgt$table$"E'i"
hl_freqs = c(250, 500, 1000, 2000, 4000, 8000)
ohc_proportion = 0.65
sn_htl = A5_HL
ohc_loss = pmin(ohc_proportion * sn_htl, 57.6)
ihc_loss = pmax(sn_htl - ohc_loss, 0)

dense_f = seq(20, 15000, by=1)
dense_l = rep(-100, length(dense_f))
dense_l = approx(x = log10(tgt$table$"Fi"), y = aided_density, xout = log10(dense_f), rule=1)$y
idx_low = which(dense_f < tgt$table$"Fi"[1])
if (length(idx_low) > 0) {
  octaves_below = log2(tgt$table$"Fi"[1] / dense_f[idx_low])
  dense_l[idx_low] = aided_density[1] - 24 * octaves_below
}
last_freq = tgt$table$"Fi"[nrow(tgt$table)]
idx_high = which(dense_f > last_freq)
if (length(idx_high) > 0) {
  octaves_above = log2(dense_f[idx_high] / last_freq)
  dense_l[idx_high] = aided_density[length(aided_density)] - 24 * octaves_above
}
dense_l[is.na(dense_l)] = -100

res = calculate_loudness_chen2011(inputF = dense_f, inputLdB = dense_l, HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss, outerearcorrection='FreeField')
cat(sprintf("R Engine Monaural Sones: %f\n", res$Ldn))

# Export exactly what was passed
cat("Freq,Level\n", file="exact_1hz_spectrum.csv")
for(i in 1:length(dense_f)){
  cat(sprintf("%f,%f\n", dense_f[i], dense_l[i]), file="exact_1hz_spectrum.csv", append=TRUE)
}
cat("exact_1hz_spectrum.csv generated.\n")
