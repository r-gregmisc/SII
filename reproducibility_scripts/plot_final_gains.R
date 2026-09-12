library(ggplot2)
library(dplyr)
library(tidyr)

devtools::load_all(".", quiet=TRUE)
source("R/benchmark_targets.R")

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
df_list <- list()

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
levels <- c(50, 65, 80)

cat("Dynamically generating plot data (this will take a few minutes)...\n")

for (p in profiles) {
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  target_data <- jd2011_targets[[p]]
  
  # Calculate 65 dB target first to use as constraint
  opennl_65 <- open_nl(speech=65, threshold=target_data$threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
  
  for (lvl in levels) {
    cat(sprintf("Evaluating %s at %d dB SPL...\n", toupper(p), lvl))
    
    # NAL-NL2
    nal_raw <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
    nal_interp <- approx(log10(target_data$freq), nal_raw, log10(freqs), rule=2)$y
    
    # Open-NL
    if (lvl == 65) {
      opennl_gains <- opennl_65$gain
    } else {
      res_opennl <- open_nl(speech=lvl, threshold=target_data$threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60, constraint_gain=opennl_65$gain)
      opennl_gains <- res_opennl$gain
    }
    
    df_list[[length(df_list) + 1]] <- data.frame(
      Profile = toupper(p),
      Level = factor(lvl, levels=c("50", "65", "80")),
      Method = "NAL-NL2",
      Frequency = freqs,
      Gain = nal_interp
    )
    
    df_list[[length(df_list) + 1]] <- data.frame(
      Profile = toupper(p),
      Level = factor(lvl, levels=c("50", "65", "80")),
      Method = "Open-NL",
      Frequency = freqs,
      Gain = opennl_gains
    )
  }
}

df <- do.call(rbind, df_list)

# Prettify profile names
profile_names <- c("A1" = "A1 (Mild)", "A2" = "A2 (Rev Slope)", "A3" = "A3 (Mod Sloping)", 
                   "A4" = "A4 (Severe)", "A5" = "A5 (Profound)", "A6" = "A6 (Mixed)", "A7" = "A7 (Conductive)")
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
