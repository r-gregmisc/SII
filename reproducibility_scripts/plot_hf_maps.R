#!/usr/bin/env Rscript

library(ggplot2)

grid_df <- read.csv("data_output/feasibility_grid.csv")
nal_df <- read.csv("data_output/feasibility_nal.csv")
profiles <- c("a4", "a5")

for (p in profiles) {
  p_grid <- grid_df[grid_df$Profile == p, ]
  p_nal <- nal_df[nal_df$Profile == p, ]
  
  max_val <- ceiling(max(p_grid$HF_Gain, na.rm=TRUE) / 5) * 5
  
  g <- ggplot(p_grid, aes(x = L_cap, y = vent_floor, z = HF_Gain)) +
    geom_contour_filled(breaks=seq(0, max_val, by=5)) +
    geom_point(data = p_nal, aes(x = L_cap, y = LF_Gain), color="red", size=4, shape=4) +
    annotate("text", x = p_nal$L_cap, y = p_nal$LF_Gain + 1, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("Feasibility Map - Profile", toupper(p)),
         x = "Loudness Cap (sones)", y = "Low-Frequency Insertion Gain Floor (dB)",
         fill = "Achievable HF Gain\n(2-4 kHz)") +
    theme_minimal()
    
  ggsave(sprintf("figures/feasibility_%s.png", p), plot=g, width=6, height=5, bg="white")
}
cat("Updated HF Gain maps in figures/feasibility_a4.png and figures/feasibility_a5.png\n")
