#!/usr/bin/env Rscript
# Reproducibility script for Table III: Effective Compression Ratios (50 to 80 dB SPL inputs)
# Directly linked to the validated gains in plot_final_gains.R

source("reproducibility_scripts/plot_final_gains.R")

cat("\n**TABLE III. Effective Compression Ratios (50 to 80 dB SPL Inputs) across A1-A7 Audiograms.**\n\n")
cat("| Profile | Formula | 250 Hz | 500 Hz | 1000 Hz | 2000 Hz | 4000 Hz | 8000 Hz |\n")
cat("|---------|---------|--------|--------|---------|---------|---------|---------|\n")

profiles <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

for (p in profiles) {
  for (method in c("NAL-NL2", "Open-NL")) {
    g50 <- data_raw[[p]][["50"]][[method]]
    g80 <- data_raw[[p]][["80"]][[method]]
    
    cr <- 30 / (30 + g80 - g50)
    cr[cr < 1.0] <- 1.0
    
    # Format strings
    cr_strs <- sapply(seq_along(cr), function(i) {
      if (g50[i] == 0 && g80[i] == 0) return("-")
      return(sprintf("%.2f", cr[i]))
    })
    
    cat(sprintf("| %s | %s | %s | %s | %s | %s | %s | %s |\n",
                p, method, cr_strs[1], cr_strs[2], cr_strs[3], cr_strs[4], cr_strs[5], cr_strs[6]))
  }
}
