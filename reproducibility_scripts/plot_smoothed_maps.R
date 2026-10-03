#!/usr/bin/env Rscript
library(ggplot2)

grid_df <- read.csv("data_output/feasibility_grid.csv")
nal_df <- read.csv("data_output/feasibility_nal.csv")
profiles <- c("a4", "a5")

for (p in profiles) {
  p_grid <- grid_df[grid_df$Profile == p, ]
  p_nal <- nal_df[nal_df$Profile == p, ]
  
  # Smooth HF Gain
  m_hf <- loess(HF_Gain ~ L_cap * vent_floor, data=p_grid, span=0.5)
  p_grid$HF_Gain_smooth <- predict(m_hf, p_grid)
  
  # Smooth SII
  m_sii <- loess(SII ~ L_cap * vent_floor, data=p_grid, span=0.5)
  p_grid$SII_smooth <- predict(m_sii, p_grid)
  
  # Replot HF Gain
  max_val <- ceiling(max(p_grid$HF_Gain_smooth, na.rm=TRUE) / 5) * 5
  g1 <- ggplot() +
    geom_contour_filled(data=p_grid, aes(x = L_cap, y = vent_floor, z = HF_Gain_smooth), breaks=seq(0, max_val, by=5)) +
    geom_point(data = p_nal, aes(x = L_cap, y = LF_Gain), color="red", size=4, shape=4) +
    annotate("text", x = p_nal$L_cap, y = p_nal$LF_Gain + 1, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("Feasibility Map - Profile", toupper(p)),
         x = "Loudness Cap (sones)", y = "Low-Frequency Insertion Gain Floor (dB)",
         fill = "Achievable HF Gain\n(2-4 kHz)") +
    theme_minimal()
  ggsave(sprintf("figures/feasibility_%s.png", p), plot=g1, width=6, height=5, bg="white")
  
  # Replot SII
  min_sii <- floor(min(p_grid$SII_smooth, na.rm=TRUE)*20)/20
  max_sii <- ceiling(max(p_grid$SII_smooth, na.rm=TRUE)*20)/20
  g2 <- ggplot() +
    geom_contour_filled(data=p_grid, aes(x = L_cap, y = vent_floor, z = SII_smooth), breaks=seq(min_sii, max_sii, by=0.05)) +
    geom_point(data = p_nal, aes(x = L_cap, y = LF_Gain), color="red", size=4, shape=4) +
    annotate("text", x = p_nal$L_cap, y = p_nal$LF_Gain + 1, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("SII Feasibility Map - Profile", toupper(p)),
         x = "Loudness Cap (sones)", y = "Low-Frequency Insertion Gain Floor (dB)",
         fill = "Achievable\nDesensitized SII") +
    theme_minimal()
  ggsave(sprintf("figures/feasibility_sii_%s.png", p), plot=g2, width=6, height=5, bg="white")
}
cat("Generated smoothed maps.\n")
