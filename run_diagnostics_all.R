library(devtools)
load_all()

freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)

cat("\n--- NAL-NL2 LDN-H Results ---\n")
jd_a4_gain <- get_jd2011_target("a4", "NAL-NL2", freqs)
s_a4_nal <- sii(speech="normal", threshold=c(0, 0, 10, 40, 70, 80, 80, 80), loss=rep(0, 8), freq=freqs, custom_gain=jd_a4_gain, interpolate=TRUE)
l_a4_nal <- calculate_loudness(s_a4_nal)

jd_a5_gain <- get_jd2011_target("a5", "NAL-NL2", freqs)
s_a5_nal <- sii(speech="normal", threshold=c(10, 10, 20, 60, 80, 100, 100, 100), loss=rep(0, 8), freq=freqs, custom_gain=jd_a5_gain, interpolate=TRUE)
l_a5_nal <- calculate_loudness(s_a5_nal)

cat(sprintf("A4 (Severe Flat)   -> NAL-NL2 Loudness: %.1f sones\n", l_a4_nal))
cat(sprintf("A5 (Profound Slope)-> NAL-NL2 Loudness: %.1f sones\n", l_a5_nal))

