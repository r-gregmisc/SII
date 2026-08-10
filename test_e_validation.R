library(devtools)
load_all()

# Load specific 1Hz spectrum
dense_l = read.csv("exact_1hz_spectrum.csv")$Level
dense_f = read.csv("exact_1hz_spectrum.csv")$Freq

A5_HL = c(10, 10, 20, 60, 80, 100)
hl_freqs = c(250, 500, 1000, 2000, 4000, 8000)
ohc_proportion = 0.65
sn_htl = A5_HL
ohc_loss = pmin(ohc_proportion * sn_htl, 57.6)
ihc_loss = pmax(sn_htl - ohc_loss, 0)

res = calculate_loudness_chen2011(inputF = dense_f, inputLdB = dense_l, HLcf = hl_freqs, HLohcdB0 = ohc_loss, HLihcdB0 = ihc_loss, outerearcorrection='FreeField')

cat("E_R\n", file="r_excitation.csv")
for(i in 1:length(res$E)){
  cat(sprintf("%e\n", res$E[i]), file="r_excitation.csv", append=TRUE)
}
