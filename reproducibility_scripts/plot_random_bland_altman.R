# plot_random_bland_altman.R
# Plots the results of the randomized AMT evaluation (50 points)

library(ggplot2)
library(dplyr)

cpp_data <- read.csv("cpp_random_results.csv")
if (!file.exists("amt_random_results.csv")) {
  stop("Missing amt_random_results.csv! Run 'octave --no-gui evaluate_random_amt.m' first.")
}
amt_data <- read.csv("amt_random_results.csv")

merged <- inner_join(cpp_data, amt_data, by=c("id", "level"))
merged$diff <- merged$cpp_loudness - merged$amt_loudness
merged$mean_val <- (merged$cpp_loudness + merged$amt_loudness) / 2

mean_diff <- mean(merged$diff)
sd_diff <- sd(merged$diff)
upper_loa <- mean_diff + 1.96 * sd_diff
lower_loa <- mean_diff - 1.96 * sd_diff

# Calculate Pearson's r
pearson_r <- cor(merged$cpp_loudness, merged$amt_loudness)

cat(sprintf("Randomized Bland-Altman Stats (N=%d):\n", nrow(merged)))
cat(sprintf("Pearson's r: %.4f\n", pearson_r))
cat(sprintf("Mean Bias: %.4f sones\n", mean_diff))
cat(sprintf("95%% LoA: [%.4f, %.4f] sones\n", lower_loa, upper_loa))
cat(sprintf("MAE: %.4f sones\n", mean(abs(merged$diff))))

# Generate Plot
p <- ggplot(merged, aes(x = mean_val, y = diff)) +
  geom_point(alpha = 0.6, color = "blue", size = 2) +
  geom_hline(yintercept = mean_diff, color = "red", linetype = "solid", linewidth = 1) +
  geom_hline(yintercept = upper_loa, color = "darkred", linetype = "dashed", linewidth = 1) +
  geom_hline(yintercept = lower_loa, color = "darkred", linetype = "dashed", linewidth = 1) +
  labs(title = "Bland-Altman Plot: Open-NL (C++) vs AMT (Octave)",
       subtitle = sprintf("N = %d Random Profiles | Bias = %.3f Sones | r = %.4f", nrow(merged), mean_diff, pearson_r),
       x = "Mean Loudness (Sones)",
       y = "Difference (C++ - AMT) [Sones]") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face="bold"),
        plot.subtitle = element_text(hjust = 0.5))

ggsave("bland_altman_validation.png", p, width=8, height=6, dpi=300)
cat("\nSaved plot to 'bland_altman_validation.png'\n")
