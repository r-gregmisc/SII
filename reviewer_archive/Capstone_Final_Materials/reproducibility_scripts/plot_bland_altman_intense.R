# plot_bland_altman_intense.R
library(ggplot2)
results_amt <- read.csv('amt_intense_results.csv')
results_cpp <- read.csv('cpp_loudness_intense.csv')
df <- merge(results_amt, results_cpp, by=c('profile', 'level'))
df$diff <- df$cpp_loudness - df$amt_loudness
df$mean <- (df$cpp_loudness + df$amt_loudness) / 2
bias <- mean(df$diff)
sd_diff <- sd(df$diff)
upper_loa <- bias + 1.96 * sd_diff
lower_loa <- bias - 1.96 * sd_diff
cat('True Bias:', bias, '\nLimits:', lower_loa, upper_loa, '\nMAE:', mean(abs(df$diff)), '\n')

p <- ggplot(df, aes(x = mean, y = diff)) +
  geom_point(aes(color = profile), size = 3, alpha = 0.8) +
  geom_hline(yintercept = bias, color = 'blue', linetype = 'solid', linewidth = 1) +
  geom_hline(yintercept = upper_loa, color = 'red', linetype = 'dashed', linewidth = 1) +
  geom_hline(yintercept = lower_loa, color = 'red', linetype = 'dashed', linewidth = 1) +
  theme_minimal() +
  labs(title = 'Bland-Altman Agreement: Open-NL C++ vs AMT bramslow2004 (True Broadband)',
       x = 'Mean Loudness (Sones)',
       y = 'Difference (C++ - AMT)')
ggsave('figures/Figure2_BlandAltman.png', p, width = 7, height = 5, dpi = 300)
cat("Figure saved to figures/Figure2_BlandAltman.png\n")
