source("R/sii.R")
source("R/open_nl.R")
source("R/moore_glasberg.R")

freq <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- c(10, 20, 40, 50, 55, 60)

res <- sii(speech = 65, noise = 0, threshold = threshold, method = "critical", prescription = "NAL-NL2")
l_uni <- calculate_loudness(res)
l_bin <- calculate_binaural_loudness(res, res)

cat(sprintf("A-3 NAL-NL2 Unilateral Loudness: %.2f sones\n", l_uni))
cat(sprintf("A-3 NAL-NL2 Binaural Loudness: %.2f sones\n", l_bin))
