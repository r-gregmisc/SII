library(ggplot2)
library(dplyr)

amt <- read.csv("amt_intense_results.csv")
cpp <- read.csv("cpp_loudness_intense.csv")
amt$profile <- tolower(amt$profile)
cpp$profile <- tolower(cpp$profile)

df <- merge(amt, cpp, by=c("profile", "level"))

# Log-transformed calculations
df$log_amt <- log(df$amt_loudness)
df$log_cpp <- log(df$cpp_loudness)
df$log_mean <- (df$log_amt + df$log_cpp) / 2
df$log_diff <- df$log_cpp - df$log_amt

mean_log_diff <- mean(df$log_diff, na.rm = TRUE)
sd_log_diff <- sd(df$log_diff, na.rm = TRUE)
loa_lower_log <- mean_log_diff - 1.96 * sd_log_diff
loa_upper_log <- mean_log_diff + 1.96 * sd_log_diff

# Transform back to ratios for plotting
df$ratio <- df$cpp_loudness / df$amt_loudness
df$mean_linear <- (df$amt_loudness + df$cpp_loudness) / 2

mean_ratio <- exp(mean_log_diff)
loa_lower_ratio <- exp(loa_lower_log)
loa_upper_ratio <- exp(loa_upper_log)

p <- ggplot(df, aes(x = mean_linear, y = ratio, color = profile)) +
  geom_hline(yintercept = mean_ratio, linetype = "dashed", color = "black") +
  geom_hline(yintercept = loa_lower_ratio, linetype = "dotted", color = "gray50") +
  geom_hline(yintercept = loa_upper_ratio, linetype = "dotted", color = "gray50") +
  geom_point(size = 3, alpha = 0.8) +
  theme_minimal() +
  scale_y_continuous(labels = scales::percent_format(), breaks = seq(0.8, 1.2, 0.05)) +
  labs(
    title = "Log-Transformed Agreement: Open-NL vs AMT",
    x = "Mean Loudness (Sones)",
    y = "Ratio (Open-NL / AMT)",
    color = "Profile"
  )

ggsave("figures/Figure2_BlandAltman.png", plot = p, width = 8, height = 5, dpi = 300)
