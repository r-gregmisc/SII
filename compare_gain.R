library(devtools)
load_all()

freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
a4_hl <- c(50, 50, 55, 65, 70, 75, 80, 80)
a5_hl <- c(60, 65, 70, 75, 85, 90, 95, 95)

# NAL-NL2 IG is generated inside the sii() function if prescription="NAL-NL2"
s_a4_nal <- sii(speech="normal", threshold=a4_hl, loss=rep(0, 8), freq=freqs, prescription="NAL-NL2", experience="experienced", interpolate=TRUE)
s_a4_open <- sii(speech="normal", threshold=a4_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)

cat("A4 NAL-NL2 IG:\n")
print(round(s_a4_nal$ig, 1))
cat("A4 Open-NL IG:\n")
print(round(s_a4_open$ig, 1))

s_a5_nal <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="NAL-NL2", experience="experienced", interpolate=TRUE)
s_a5_open <- sii(speech="normal", threshold=a5_hl, loss=rep(0, 8), freq=freqs, prescription="Open-NL", experience="experienced", interpolate=TRUE)

cat("\nA5 NAL-NL2 IG:\n")
print(round(s_a5_nal$ig, 1))
cat("A5 Open-NL IG:\n")
print(round(s_a5_open$ig, 1))

