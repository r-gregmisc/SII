
library(ggplot2)
library(dplyr)
library(tidyr)
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

thresholds_to_sweep <- seq(0, 80, by = 10)
penalties_to_sweep <- seq(0, 30, by = 5)

results <- data.frame()
original_file <- readLines("R/nalr.R")
on.exit(writeLines(original_file, "R/nalr.R"))

for (thresh in thresholds_to_sweep) {
  for (pen in penalties_to_sweep) {
    
    # Modify nalr.R in memory from the original, untampered source
    mod_file <- original_file
    mod_file <- gsub("if \\(slope_diff > 15\\) \\{", sprintf("if (slope_diff > %d) {", thresh), mod_file)
    mod_file <- gsub("lf_penalty_factor <- pmin\\(1, \\(slope_diff - 15\\) / 20\\)", sprintf("lf_penalty_factor <- pmin(1, (slope_diff - %d) / 20)", thresh), mod_file)
    mod_file <- gsub("lf_penalty_max <- lf_penalty_factor \\* 15 #", sprintf("lf_penalty_max <- lf_penalty_factor * %d #", pen), mod_file)
    
    writeLines(mod_file, "R/nalr.R")
    source("R/nalr.R")
    source("R/open_nl.R")
    
    for (pname in names(profiles)) {
      p <- profiles[[pname]]
      # If it's the conductive profile, simulate a 50 dB flat ABG
      if (pname == "A7") {
        abg <- rep(50, 6)
      } else if (pname == "A6") {
        abg <- rep(30, 6)
      } else {
        abg <- rep(0, 6)
      }
      
      tgt <- open_nl(65, threshold = p, freq = freqs, loss = abg)
      # We evaluate the SII strictly on the generated target against the pure threshold/loss
      res <- sii(speech = tgt$speech + tgt$gain, noise = rep(-100, 6), threshold = p, loss = abg, freq = freqs, prescription = NULL, method = "octave")
      
      ldn <- calculate_loudness(res)
      
      results <- rbind(results, data.frame(
        Profile = pname,
        Slope = slopes[pname],
        Threshold = thresh,
        MaxPenalty = pen,
        Sones = ldn
      ))
    }
  }
}

# Restore original file
writeLines(original_file, "R/nalr.R")

# Prettify labels
results$ProfileLabel <- sprintf("%s (Slope: %.1f)", results$Profile, results$Slope)
# Order facets by slope
ordered_labels <- unique(results$ProfileLabel[order(results$Slope)])
results$ProfileLabel <- factor(results$ProfileLabel, levels = ordered_labels)

# Generate Faceted 2D Heatmap
p <- ggplot(results, aes(x = as.factor(Threshold), y = as.factor(MaxPenalty), fill = Sones)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.1f", Sones)), color = ifelse(results$Sones < max(results$Sones)/2, "white", "black"), size = 2.5) +
  facet_wrap(~ProfileLabel, scales = "free", ncol=4) +
  scale_fill_viridis_c(option = "magma", name = "Loudness\n(sones)", limits = c(0, max(results$Sones))) +
  labs(
    title = "2D Sensitivity Surface: SD-LFP Parameters Across A1-A7 Profiles",
    subtitle = "Varying Slope Threshold and Max Penalty on physiological loudness (sones)",
    x = "Slope Threshold Parameter (dB)",
    y = "Maximum Allowed Penalty (dB)"
  ) +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave("Figure4_Sensitivity.png", p, width = 12, height = 8, dpi = 300)
cat("Successfully generated Figure4_Sensitivity.png\n")
