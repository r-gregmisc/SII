library(SII)
source("R/benchmark_targets.R")

calc_amt_loudness <- function(gain_tgt, htl, cond, target_level) {
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_spec <- normal_speech + (target_level - overall_normal)
  
  sii_obj <- sii(speech = speech_spec, threshold = htl, loss = cond, freq = freqs, method = "octave", transducer = "none", custom_gain = gain_tgt, desensitization = FALSE)
  l_res <- calculate_loudness(sii_obj)
  return(if (is.list(l_res)) l_res$total else l_res)
}

# Try Bilateral vs Unilateral NAL-NL2 gains?
# JD2011 targets are for what config?
# The paper Johnson & Dillon (2011) gives targets.
# Let's just print NAL-NL2 loudness for ALL presets, and open-nl for ALL configs!
for (p in c("a1", "a2", "a3", "a4", "a5", "a6", "a7")) {
  htl <- jd2011_targets[[p]]$threshold
  nal_tgt <- get_jd2011_target(p, "NAL-NL2", c(250, 500, 1000, 2000, 4000, 8000), 65)
  nal_loud <- calc_amt_loudness(nal_tgt, htl, rep(0, 6), 65)
  cat(p, "NAL-NL2:", nal_loud, "\n")
}
