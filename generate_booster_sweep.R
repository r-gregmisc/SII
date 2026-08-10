
library(ggplot2)
library(dplyr)
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) source(f)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- list(
  A1 = c(15, 20, 30, 40, 50, 60),
  A2 = c(60, 50, 40, 30, 20, 15),
  A3 = c(10, 20, 40, 50, 55, 60),
  A4 = c(0, 0, 10, 40, 70, 80),
  A5 = c(10, 10, 20, 60, 80, 100),
  A6 = c(50, 55, 60, 65, 75, 80),
  A7 = c(50, 50, 50, 50, 50, 50)
)
slopes <- sapply(profiles, function(p) mean(p[4:6]) - mean(p[1:3]))

breakpoints <- c(60, 65, 70, 75, 80)
slopes_to_sweep <- c(0.00, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30)

results <- data.frame()
original_file <- readLines("R/nalr.R")
on.exit(writeLines(original_file, "R/nalr.R"))

for (bp in breakpoints) {
  for (sl in slopes_to_sweep) {
    
    mod_file <- original_file
    # Replace exactly: g_base <- g_base + 0.15 * pmax(0, sn_threshold - 60)
    mod_file <- gsub("g_base <- g_base \\+ 0\\.15 \\* pmax\\(0, sn_threshold - 60\\)", 
                     sprintf("g_base <- g_base + %f * pmax(0, sn_threshold - %d)", sl, bp), 
                     mod_file)
    
    writeLines(mod_file, "R/nalr.R")
    source("R/nalr.R")
    source("R/open_nl.R")
    
    for (pname in names(profiles)) {
      p <- profiles[[pname]]
      if (pname == "A7") {
        abg <- rep(50, 6)
      } else if (pname == "A6") {
        abg <- rep(30, 6)
      } else {
        abg <- rep(0, 6)
      }
      
      tgt <- open_nl(65, threshold = p, freq = freqs, loss = abg)
      res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = p, loss = abg, freq = freqs, prescription = NULL, method = "octave")
      ldn <- calculate_loudness(res)
      
      results <- rbind(results, data.frame(
        Profile = pname,
        Slope = slopes[pname],
        Breakpoint = bp,
        BoosterSlope = sl,
        Sones = ldn
      ))
    }
  }
}

# Restore original file
writeLines(original_file, "R/nalr.R")

# Prettify labels
results$ProfileLabel <- sprintf("%s (Slope: %.1f)", results$Profile, results$Slope)
ordered_labels <- unique(results$ProfileLabel[order(results$Slope)])
results$ProfileLabel <- factor(results$ProfileLabel, levels = ordered_labels)

# Generate Faceted 2D Heatmap
p <- ggplot(results, aes(x = as.factor(Breakpoint), y = as.factor(BoosterSlope), fill = Sones)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.1f", Sones)), color = ifelse(results$Sones < max(results$Sones)/2, "white", "black"), size = 2.5) +
  facet_wrap(~ProfileLabel, scales = "free", ncol=4) +
  scale_fill_viridis_c(option = "magma", name = "Loudness\n(sones)", limits = c(0, max(results$Sones))) +
  labs(
    title = "2D Sensitivity Surface: Severe-Loss Booster Parameters",
    subtitle = "Varying Booster Breakpoint (dB HL) and Magnitude (Slope) on physiological loudness",
    x = "Booster Breakpoint (dB HL)",
    y = "Booster Magnitude (Slope)"
  ) +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("Figure5_Booster.png", p, width = 12, height = 8, dpi = 300)
cat("Successfully generated Figure5_Booster.png\n")
