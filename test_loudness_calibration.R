library(devtools)
load_all()

# Generate normal hearing spectrum for 65 dB SPL ILTASS
# SII speech="normal" generates a 65 dB SPL overall free-field speech spectrum
s <- sii(speech="normal", threshold=rep(0,6), loss=rep(0,6), freq=c(250,500,1000,2000,4000,8000), interpolate=TRUE)
l <- calculate_loudness(s)

cat(sprintf("Calibration Check (Normal Hearing, 65 dB SPL): %.2f sones\n", l))
