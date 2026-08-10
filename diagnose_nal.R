library(devtools)
load_all()

freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)

s_a5_nal <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="NAL-NL2", experience="experienced", interpolate=TRUE)
cat("A5 NAL-NL2 E'i:\n")
print(round(s_a5_nal$table$"E'i", 1))
cat("A5 NAL-NL2 Loudness:", calculate_loudness(s_a5_nal), "\n")
