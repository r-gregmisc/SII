
source("R/sii.R")
source("R/nalr.R")
source("R/open_nl.R")
source("R/moore_glasberg.R")
freqs <- c(250, 500, 1000, 2000, 3000, 4000, 6000, 8000)
a4 <- c(15, 25, 40, 75, 80, 80, 80, 80)
temp_target <- list(
        freq = freqs, gain = rep(10, 8), mpo = rep(100, 8), speech = rep(65, 8),
        threshold = a4, loss = rep(0, 8), module = "standard", overall_level = 65
)
class(temp_target) <- "prescription_target"
res <- sii(speech = rep(65, 8), noise = rep(-50, 8), threshold = a4, loss = rep(0, 8), freq = freqs, prescription = temp_target, interpolate = TRUE, nal_ldf = TRUE, desensitization = TRUE)
loud <- calculate_loudness(res)
cat("SII:", res$sii, "Loudness:", loud$total, "
")
