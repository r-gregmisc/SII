source("R/benchmark_targets.R")
source("R/sii.R")
source("R/moore_glasberg.R")

calc_amt_loudness_new <- function(gain_tgt, htl, cond, target_level) {
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  load("data/critical.rda")
  normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_spec <- normal_speech + (target_level - overall_normal)
  
  sii_obj <- sii(speech=speech_spec, threshold=htl, loss=cond, freq=freqs, method="octave", transducer="none", custom_gain=gain_tgt, desensitization=FALSE)
  return(calculate_binaural_loudness(sii_obj))
}

p <- "a1"
htl <- jd2011_targets[[p]]$threshold
cond <- rep(0, 6)
nal_tgt <- get_jd2011_target(p, "NAL-NL2", c(250, 500, 1000, 2000, 4000, 8000), 65)

cat("New Native NAL-NL2 A1: ", calc_amt_loudness_new(nal_tgt, htl, cond, 65), "\n")
cat("New Native Unaided A1: ", calc_amt_loudness_new(rep(0,6), htl, cond, 65), "\n")
