library(ggplot2)
library(dplyr)
library(tidyr)

# Hardcoded data from the final validation table
data_raw <- list(
  A1 = list(
    `50` = list(`NAL-NL2`=c(0.3, 2.0, 12.4, 19.5, 25.6, 25.5), `Open-NL`=c(6.0, 0.0, 9.5, 16.2, 27.3, 26.2)),
    `65` = list(`NAL-NL2`=c(0.0, 0.0, 7.3, 12.1, 18.0, 19.1), `Open-NL`=c(0.0, 0.0, 8.5, 11.2, 19.7, 18.1)),
    `80` = list(`NAL-NL2`=c(0.0, 0.0, 0.2, 2.7, 7.0, 9.3), `Open-NL`=c(0.0, 0.0, 4.7, 5.7, 10.5, 3.1))
  ),
  A2 = list(
    `50` = list(`NAL-NL2`=c(15.8, 17.3, 18.7, 14.2, 8.6, 6.6), `Open-NL`=c(18.3, 15.1, 17.6, 14.1, 10.2, 5.2)),
    `65` = list(`NAL-NL2`=c(10.1, 9.3, 12.2, 8.3, 3.9, 4.0), `Open-NL`=c(7.4, 10.2, 14.0, 10.7, 9.7, 4.4)),
    `80` = list(`NAL-NL2`=c(0.0, 0.0, 3.2, 0.3, 0.0, 0.0), `Open-NL`=c(0.0, 2.7, 6.5, 2.2, 0.0, 0.0))
  ),
  A3 = list(
    `50` = list(`NAL-NL2`=c(0.0, 2.7, 15.9, 24.4, 28.2, 27.8), `Open-NL`=c(0.0, 0.0, 18.7, 24.7, 28.5, 22.0)),
    `65` = list(`NAL-NL2`=c(0.0, 0.0, 9.9, 16.8, 20.7, 21.6), `Open-NL`=c(0.0, 0.0, 13.8, 16.8, 18.5, 7.0)),
    `80` = list(`NAL-NL2`=c(0.0, 0.0, 1.9, 6.5, 9.3, 11.5), `Open-NL`=c(0.0, 0.0, 8.1, 8.4, 9.7, 0.0))
  ),
  A4 = list(
    `50` = list(`NAL-NL2`=c(0.0, 0.0, 3.1, 19.2, 27.8, 26.6), `Open-NL`=c(0.0, 0.0, 0.0, 6.7, 41.5, 38.4)),
    `65` = list(`NAL-NL2`=c(0.0, 0.0, 0.9, 12.5, 21.8, 21.8), `Open-NL`=c(0.0, 0.0, 0.0, 0.0, 29.0, 38.4)),
    `80` = list(`NAL-NL2`=c(0.0, 0.0, 0.0, 3.0, 11.3, 12.6), `Open-NL`=c(0.0, 0.0, 0.0, 0.0, 14.0, 23.4))
  ),
  A5 = list(
    `50` = list(`NAL-NL2`=c(0.0, 0.0, 11.3, 26.8, 32.1, 30.9), `Open-NL`=c(0.0, 0.0, 0.0, 7.4, 38.8, 33.2)),
    `65` = list(`NAL-NL2`=c(0.0, 0.0, 6.6, 20.7, 27.1, 26.6), `Open-NL`=c(0.0, 0.0, 0.0, 5.5, 25.3, 18.2)),
    `80` = list(`NAL-NL2`=c(0.0, 0.0, 0.2, 11.0, 17.2, 17.7), `Open-NL`=c(0.0, 0.0, 0.0, 0.0, 17.9, 15.8))
  ),
  A6 = list(
    `50` = list(`NAL-NL2`=c(28.0, 28.0, 29.5, 37.7, 42.3, 48.2), `Open-NL`=c(28.6, 36.4, 42.8, 44.1, 48.2, 39.0)),
    `65` = list(`NAL-NL2`=c(22.5, 24.2, 32.9, 35.6, 41.4, 42.6), `Open-NL`=c(23.6, 31.4, 37.8, 39.1, 43.2, 34.0)),
    `80` = list(`NAL-NL2`=c(20.7, 20.7, 20.7, 26.3, 27.3, 31.6), `Open-NL`=c(18.6, 26.4, 32.8, 34.1, 38.2, 29.0))
  ),
  A7 = list(
    `50` = list(`NAL-NL2`=c(34.7, 34.6, 34.7, 34.8, 35.0, 35.1), `Open-NL`=c(37.5, 37.5, 37.5, 37.5, 37.5, 37.5)),
    `65` = list(`NAL-NL2`=c(34.7, 34.6, 34.7, 34.8, 35.0, 35.1), `Open-NL`=c(37.5, 37.5, 37.5, 37.5, 37.5, 37.5)),
    `80` = list(`NAL-NL2`=c(34.7, 34.6, 34.7, 34.8, 35.0, 35.1), `Open-NL`=c(37.5, 37.5, 37.5, 37.5, 37.5, 37.5))
  )
)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
df_list <- list()

for (p in names(data_raw)) {
  for (lvl in names(data_raw[[p]])) {
    for (method in names(data_raw[[p]][[lvl]])) {
      gains <- data_raw[[p]][[lvl]][[method]]
      df_list[[length(df_list) + 1]] <- data.frame(
        Profile = p,
        Level = factor(lvl, levels=c("50", "65", "80")),
        Method = method,
        Frequency = freqs,
        Gain = gains
      )
    }
  }
}

df <- do.call(rbind, df_list)

# Prettify profile names
profile_names <- c("A1" = "A1 (Mild)", "A2" = "A2 (Rev Slope)", "A3" = "A3 (Mod Sloping)", 
                   "A4" = "A4 (Mod-Severe)", "A5" = "A5 (Profound)", "A6" = "A6 (Mixed)", "A7" = "A7 (Conductive)")
df$Profile <- factor(profile_names[as.character(df$Profile)], levels = profile_names)

# Custom colors and line types for clarity
colors <- c("NAL-NL2" = "#E66100", "Open-NL" = "#5D3A9B")

p <- ggplot(df, aes(x = Frequency, y = Gain, color = Method, linetype = Level, group = interaction(Method, Level))) +
  geom_line(size = 1.0) +
  geom_point(size = 2.0) +
  scale_x_log10(breaks = freqs, labels = freqs) +
  scale_color_manual(values = colors) +
  scale_linetype_manual(values = c("50" = "dotted", "65" = "solid", "80" = "twodash")) +
  facet_wrap(~ Profile, ncol = 4) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Prescriptive Gain Targets: Open-NL vs NAL-NL2",
    subtitle = "Inputs at 50, 65, and 80 dB SPL across seven canonical audiometric profiles",
    x = "Frequency (Hz)",
    y = "Insertion Gain (dB)",
    color = "Prescription",
    linetype = "Input Level (dB SPL)"
  ) +
  theme(
    legend.position = "bottom",
    legend.box = "vertical",
    strip.text = element_text(face = "bold", size = 12),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = "grey80", fill = NA, size = 1)
  )

dir.create("/home/mark/Development/SII-github/manuscript_figures", showWarnings = FALSE)
ggsave("/home/mark/Development/SII-github/manuscript_figures/OpenNL_vs_NALNL2_Gain_Final.png", plot = p, width = 12, height = 10, dpi = 300)
ggsave("/home/mark/.gemini/antigravity/brain/d1572c05-6279-48ca-983d-ed6e97ed4c47/OpenNL_vs_NALNL2_Gain_Final.png", plot = p, width = 12, height = 10, dpi = 300)
