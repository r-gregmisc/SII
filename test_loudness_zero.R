source("R/benchmark_targets.R")
source("R/sii.R")
source("R/nalr.R")
source("R/moore_glasberg.R")

data <- jd2011_targets[["a7"]]
freq <- data$freq
threshold <- data$threshold
gain <- get_jd2011_target("a7", "NAL-NL2", target_freqs = freq, level = 65)

res <- sii(speech = "normal", 
           threshold = threshold, 
           freq = freq, 
           method = "octave", 
           custom_gain = gain)
cat("SII:", res$sii, "\n")
sone_val <- calculate_loudness(res)
cat("Sones:", sone_val, "\n")
