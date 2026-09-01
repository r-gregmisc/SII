library(SII)
source("R/benchmark_targets.R")

calc_amt_loudness <- function(gain_tgt, htl, cond, target_level) {
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  if (!exists("critical", envir = .GlobalEnv)) {
    data("critical", package="SII", envir = .GlobalEnv)
  }
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
  
  l_res <- calculate_loudness(sii_obj)
  return(if (is.list(l_res)) l_res$total else l_res)
}

# A1
htl <- c(15, 20, 30, 40, 50, 60)
cond <- rep(0, 6)
tgt <- get_jd2011_target("a1", "NAL-NL2", c(250, 500, 1000, 2000, 4000, 8000), 65)
nalnl2_loud <- calc_amt_loudness(tgt, htl, cond, 65)

# Open-NL
source("R/open_nl.R")
source("R/nalr.R")
op_res <- open_nl(speech = 65, threshold = htl, freq = c(250, 500, 1000, 2000, 4000, 8000), loss = cond, config="bilateral")
opennl_loud <- calc_amt_loudness(op_res$gain, htl, cond, 65)

cat("A1 NAL-NL2 Loudness in Shiny logic:", sprintf("%.1f", nalnl2_loud), "\n")
cat("A1 Open-NL Loudness in Shiny logic:", sprintf("%.1f", opennl_loud), "\n")
