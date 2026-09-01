source("R/sii.R")
source("R/open_nl.R")
source("R/nalr.R")
source("R/moore_glasberg.R")
source("R/benchmark_targets.R")

library(ggplot2)
library(patchwork)

# Ensure data is loaded
local_env <- new.env()
data(list = "critical", package = "SII", envir = local_env)
critical <- get("critical", envir = local_env)

profiles <- list(
  A1 = c(15, 20, 30, 40, 50, 60),
  A2 = c(20, 30, 40, 50, 60, 70),
  A3 = c(30, 40, 50, 60, 70, 80),
  A4 = c(40, 50, 60, 70, 80, 90),
  A5 = c(50, 60, 70, 80, 90, 100),
  A6 = c(60, 70, 80, 90, 100, 110),
  A7 = c(15, 15, 15, 15, 15, 15)  # A7 is conductive, but let's use the actual A7 thresholds
)

# A7 is defined as a flat 50 dB conductive loss
if (exists("jd2011_targets")) {
  # A7 in jd2011_targets is flat 50 dB conductive loss
  profiles$A7 <- rep(50, 6)
  abg_A7 <- rep(50, 6)
}

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
f_21 <- critical$fi

plots <- list()

for (prof in names(profiles)) {
  cat("Processing", prof, "...\n")
  
  threshold <- profiles[[prof]]
  loss <- if (prof == "A7") rep(50, 6) else rep(0, 6)
  
  # Interpolate to 21 bands
  htl_21 <- approx(x = log10(hl_freqs), y = threshold, xout = log10(f_21), rule = 2)$y
  loss_21 <- approx(x = log10(hl_freqs), y = loss, xout = log10(f_21), rule = 2)$y
  
  # Run optimization
  target_opennl <- open_nl(
    speech = 65, 
    threshold = htl_21, 
    freq = f_21, 
    loss = loss_21, 
    module = "standard", 
    config = "bilateral"
  )
  
  # Evaluate with sii engine
  obj_opennl <- sii(
    speech = "normal",
    noise = rep(-50, 21),
    threshold = htl_21,
    loss = loss_21,
    freq = f_21,
    prescription = target_opennl,
    interpolate = FALSE
  )
  
  # Create plot
  p <- plot(obj_opennl, clinical = FALSE) + 
       ggtitle(paste("Open-NL:", prof)) +
       theme(legend.position = "bottom")
       
  plots[[prof]] <- p
  
  # Also print the CR from 50 to 65 and 65 to 80 for all 6 frequencies
  gains <- export_gains(obj_opennl)
  
  cat(sprintf("\n  Compression Ratios for %s:\n", prof))
  cat(sprintf("  %10s | %10s | %10s | %10s | %10s | %10s\n", "Freq (Hz)", "Gain 50dB", "Gain 65dB", "Gain 80dB", "CR 50-65", "CR 65-80"))
  cat("  --------------------------------------------------------------------------------\n")
  
  for (f in hl_freqs) {
    g_50 <- approx(x = log10(gains$Frequency), y = gains$Gain_50, xout = log10(f), rule = 2)$y
    g_65 <- approx(x = log10(gains$Frequency), y = gains$Gain_65, xout = log10(f), rule = 2)$y
    g_80 <- approx(x = log10(gains$Frequency), y = gains$Gain_80, xout = log10(f), rule = 2)$y
    
    cr_50_65 <- 15 / ((65 + g_65) - (50 + g_50))
    cr_65_80 <- 15 / ((80 + g_80) - (65 + g_65))
    
    cat(sprintf("  %10.0f | %10.1f | %10.1f | %10.1f | %10.2f | %10.2f\n", 
                f, g_50, g_65, g_80, cr_50_65, cr_65_80))
  }
  cat("\n")
}

combined_plot <- wrap_plots(plots, ncol = 3)

ggsave("open_nl_profiles_ig.png", combined_plot, width = 15, height = 12, dpi = 300)
cat("Saved plot to open_nl_profiles_ig.png\n")
