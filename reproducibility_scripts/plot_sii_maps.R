#!/usr/bin/env Rscript

library(ggplot2)

grid_df <- read.csv("data_output/feasibility_grid.csv")
nal_df <- read.csv("data_output/feasibility_nal.csv")
profiles <- c("a4", "a5")

for (p in profiles) {
  p_grid <- grid_df[grid_df$Profile == p, ]
  p_nal <- nal_df[nal_df$Profile == p, ]
  
  min_sii <- floor(min(p_grid$SII, na.rm=TRUE)*20)/20
  max_sii <- ceiling(max(p_grid$SII, na.rm=TRUE)*20)/20
  
  g <- ggplot() +
    geom_contour_filled(data = p_grid, aes(x = L_cap, y = vent_floor, z = SII), breaks=seq(min_sii, max_sii, by=0.05)) +
    geom_point(data = p_nal, aes(x = L_cap, y = LF_Gain), color="red", size=4, shape=4) +
    annotate("text", x = p_nal$L_cap, y = p_nal$LF_Gain + 1, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("SII Feasibility Map - Profile", toupper(p)),
         x = "Loudness Cap (sones)", y = "Low-Frequency Insertion Gain Floor (dB)",
         fill = "Achievable\nDesensitized SII") +
    theme_minimal()
    
  ggsave(sprintf("figures/feasibility_sii_%s.png", p), plot=g, width=6, height=5, bg="white")
}
cat("Generated SII maps in figures/feasibility_sii_a4.png and figures/feasibility_sii_a5.png\n")
