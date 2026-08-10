library(devtools)
load_all()

# Generate a 1-kHz 40 dB SPL density spectrum
# A pure tone of 40 dB SPL has all its energy at 1000 Hz.
# Since our conversion method spreads it across a 1 Hz band, it's 40 dB/Hz at 1000 Hz.
dense_f = seq(20, 20000, by=1)
dense_l = rep(-100, length(dense_f))
dense_l[dense_f == 1000] = 40

res = calculate_loudness_chen2011(inputF = dense_f, inputLdB = dense_l, outerearcorrection='FreeField')

cat(sprintf("Stage 2 Validation: 1 kHz tone at 40 dB SPL -> Monaural Sones: %f\n", res$Ldn))
