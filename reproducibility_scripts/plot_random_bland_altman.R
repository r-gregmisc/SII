# plot_random_bland_altman.R
# Plots the results of the randomized AMT evaluation (250 points)

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

cat(sprintf("Randomized Bland-Altman Stats (N=%d):\n", nrow(merged)))
cat(sprintf("Mean Bias: %.4f sones\n", mean_diff))
cat(sprintf("95%% LoA: [%.4f, %.4f] sones\n", lower_loa, upper_loa))
cat(sprintf("MAE: %.4f sones\n", mean(abs(merged$diff))))
