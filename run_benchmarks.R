library(SII)
source("R/open_nl.R")
source("inst/shiny/R/benchmark_targets.R")

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")

data("critical", package="SII")
f_21 <- critical$fi

cat("Profile\tSII_50\tSones_50\tSII_65\tSones_65\tSII_80\tSones_80\n")

for (p in profiles) {
  d <- get_jd2011_profile(p, f_21)
  
  # 50 dB
  target_50 <- open_nl(speech = 50, threshold = d$htl_6, freq = d$f_6, loss = d$loss_6)
  obj_50 <- sii(speech = 50, noise = rep(-50, length(f_21)), threshold = d$htl_21, loss = d$loss_21, freq = f_21, prescription = target_50, interpolate = TRUE)
  sii_50 <- obj_50$sii
  sones_50 <- calculate_loudness(obj_50)
  
  # 65 dB
  target_65 <- open_nl(speech = 65, threshold = d$htl_6, freq = d$f_6, loss = d$loss_6)
  obj_65 <- sii(speech = 65, noise = rep(-50, length(f_21)), threshold = d$htl_21, loss = d$loss_21, freq = f_21, prescription = target_65, interpolate = TRUE)
  sii_65 <- obj_65$sii
  sones_65 <- calculate_loudness(obj_65)
  
  # 80 dB
  target_80 <- open_nl(speech = 80, threshold = d$htl_6, freq = d$f_6, loss = d$loss_6)
  obj_80 <- sii(speech = 80, noise = rep(-50, length(f_21)), threshold = d$htl_21, loss = d$loss_21, freq = f_21, prescription = target_80, interpolate = TRUE)
  sii_80 <- obj_80$sii
  sones_80 <- calculate_loudness(obj_80)
  
  cat(sprintf("%s\t%.2f\t%.1f\t%.2f\t%.1f\t%.2f\t%.1f\n", p, sii_50, sones_50, sii_65, sones_65, sii_80, sones_80))
}
