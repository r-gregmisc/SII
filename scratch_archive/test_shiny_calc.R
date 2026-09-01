library(shiny)

# Mock Shiny inputs for A1 audiogram
input <- list(
  htl250 = 15, htl500 = 20, htl1000 = 30, htl2000 = 40, htl4000 = 50, htl8000 = 60,
  speech_level = 65, gender = "male", experience = "experienced", config = "bilateral", coupling = "open", module = "optimization",
  desensitization = FALSE, transducer = "none"
)

# Simulate what shiny does inside the reactive
library(SII)
source("R/sii.R")
source("R/nalr.R")
source("R/open_nl.R")

threshold <- c(15, 20, 30, 40, 50, 60)
loss_6 <- rep(0, 6)
target_level <- 65

target <- open_nl(speech = 65, threshold = threshold, freq = c(250,500,1000,2000,4000,8000), loss = loss_6, config = "bilateral")

calc_amt_loudness <- function(gain_tgt, htl, cond, target_level) {
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  critical <- SII:::sii_bands$critical
  normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_spec <- normal_speech + (target_level - overall_normal)

  sii_obj <- sii(
    speech = speech_spec,
    threshold = htl,
    loss = cond,
    freq = freqs,
    method = "octave",
    transducer = "none",
    custom_gain = gain_tgt,
    desensitization = FALSE
  )
  calculate_loudness(sii_obj)$total
}

val <- calc_amt_loudness(target$gain, threshold, loss_6, target_level)
cat(sprintf("\nShiny simulated LOUDNESS: %.2f\n", val))
