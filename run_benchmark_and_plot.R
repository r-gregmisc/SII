library(devtools)
load_all()
library(ggplot2)

# Run the full benchmark using the true A1-A7 audiograms from benchmark_targets.R
cat("Running full benchmark array (A1-A7)...\n")
results <- benchmark_reference_audiograms()

# Print the results so we can see the true A4 and A5 evaluations!
print(results)

# Save the corrected CSV
csv_path <- "tradeoff_results_corrected.csv"
write.csv(results, csv_path, row.names = FALSE)
cat(sprintf("\nSaved updated results to %s\n", csv_path))

# Generate the Tradeoff Plot in R for consistency
plot <- ggplot(results, aes(x = Sones, y = SII, color = Formula, shape = Formula)) +
  geom_point(size = 4, alpha = 0.8) +
  geom_vline(xintercept = 8, linetype = "dashed", color = "gray50", alpha = 0.7) +
  annotate("text", x = 8.5, y = 0.4, label = "Clinical Baseline (~8 sones)", angle = 90, color = "gray50", size = 4) +
  theme_minimal(base_size = 14) +
  coord_cartesian(xlim = c(0, 25)) +
  labs(
    title = "SII vs. Loudness Tradeoff (65 dB SPL Input)",
    subtitle = "Open-NL vs Proprietary Prescriptions across 7 Benchmark Profiles",
    x = "Predicted Loudness (Sones)",
    y = "Speech Intelligibility Index (SII)"
  ) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank(),
    plot.title = element_text(face = "bold")
  )

# Save the plot
plot_path <- "tradeoff_plot.png"
ggsave(plot_path, plot, width = 8, height = 6, dpi = 300)
cat(sprintf("Saved updated plot to %s\n", plot_path))
