#!/usr/bin/env Rscript
suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness", "calculate_open_nl_gain")), envir = .GlobalEnv))
devtools::load_all(".", reset = TRUE, quiet=TRUE)
source("R/benchmark_targets.R")
library(parallel)

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")
freqs <- c(250, 500, 1000, 2000, 4000, 8000)

cat("\n**TABLE S3. Effective Compression Ratios (50 to 80 dB SPL Inputs) across A1-A7 Audiograms.**\n\n")
cat("| Profile | Formula | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |\n")
cat("|---------|---------|--------|--------|---------|---------|---------|---------|\n")

results <- mclapply(seq_along(profiles), function(i) {
  p <- profiles[i]
  p_name <- profile_names[i]
  
  target_data <- jd2011_targets[[p]]
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  nal_65 <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, 65)
  nal_50 <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, 50)
  nal_80 <- get_nalnl2_v2_target(p, "NAL-NL2", freqs, 80)
  
  cr_nal <- 30 / (30 + nal_80 - nal_50)
  cr_nal[cr_nal < 1.0] <- 1.0
  cr_nal_strs <- sapply(seq_along(cr_nal), function(j) {
    if (nal_50[j] == 0 && nal_80[j] == 0) return("-")
    return(sprintf("%.2f", cr_nal[j]))
  })
  
  str_nal <- sprintf("| %s | NAL-NL2 | %s | %s | %s | %s | %s | %s |\n",
                     p_name, cr_nal_strs[1], cr_nal_strs[2], cr_nal_strs[3], cr_nal_strs[4], cr_nal_strs[5], cr_nal_strs[6])
  
  opennl_65 <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  opennl_50 <- open_nl(speech=50, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60, constraint_gain=opennl_65$gain)
  opennl_80 <- open_nl(speech=80, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60, constraint_gain=opennl_65$gain)
  
  diff_opennl <- opennl_50$gain - opennl_80$gain
  cr_opennl <- 30 / (30 - diff_opennl)
  cr_opennl[cr_opennl < 1.0] <- 1.0
  cr_opennl_strs <- sapply(seq_along(cr_opennl), function(j) {
    if (opennl_50$gain[j] == 0 && opennl_80$gain[j] == 0) return("-")
    return(sprintf("%.2f", cr_opennl[j]))
  })
  
  str_opennl <- sprintf("| %s | Open-NL | %s | %s | %s | %s | %s | %s |\n",
                        p_name, cr_opennl_strs[1], cr_opennl_strs[2], cr_opennl_strs[3], cr_opennl_strs[4], cr_opennl_strs[5], cr_opennl_strs[6])
  
  return(paste0(str_nal, str_opennl))
}, mc.cores = detectCores())

for (res in results) {
  cat(res)
}
