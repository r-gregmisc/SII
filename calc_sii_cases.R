library(devtools)
load_all()

# Base frequencies for default method ('critical')
freq_crit <- c(150, 250, 350, 450, 570, 700, 840, 1000, 1170, 1370, 1600, 1850, 2150, 2500, 2900, 3400, 4000, 4800, 5800, 7000, 8500)
# Base frequencies for 1/3 octave
freq_13 <- c(160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000)
# Base frequencies for octave
freq_oct <- c(250, 500, 1000, 2000, 4000, 8000)

s1 <- sii(speech=65, noise=60, threshold=rep(0, length(freq_crit)), freq=freq_crit, method="critical")$sii
s2 <- sii(speech=85, noise=30, threshold=rep(0, length(freq_crit)), freq=freq_crit, method="critical")$sii
s3 <- sii(speech=65, noise=30, threshold=rep(0, length(freq_13)), freq=freq_13, method="one_third")$sii
s4 <- sii(speech=65, noise=30, threshold=rep(0, length(freq_oct)), freq=freq_oct, method="octave")$sii

print(paste("Speech in Noise (65dB/60dB):", s1))
print(paste("High Level (85dB/30dB):", s2))
print(paste("One-Third Octave:", s3))
print(paste("Octave:", s4))
