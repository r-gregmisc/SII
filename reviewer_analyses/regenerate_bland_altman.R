library(ggplot2)
library(dplyr)

amt <- read.csv("amt_intense_results.csv")
cpp <- read.csv("cpp_loudness_intense.csv")

amt$profile <- tolower(amt$profile)
cpp$profile <- tolower(cpp$profile)

df <- merge(amt, cpp, by=c("profile", "level"))
df$mean <- (df$amt_loudness + df$cpp_loudness) / 2
df$diff <- df$cpp_loudness - df$amt_loudness

p <- ggplot(df, aes(x = mean, y = diff, color = profile)) +
  geom_hline(yintercept = mean(df$diff, na.rm=TRUE), linetype = "dashed", color = "black") +
  geom_hline(yintercept = mean(df$diff, na.rm=TRUE) + 1.96 * sd(df$diff, na.rm=TRUE), linetype = "dotted", color = "gray50") +
  geom_hline(yintercept = mean(df$diff, na.rm=TRUE) - 1.96 * sd(df$diff, na.rm=TRUE), linetype = "dotted", color = "gray50") +
  geom_point(size = 3, alpha = 0.8) +
  theme_minimal() +
  labs(
    title = "Agreement: Open-NL vs AMT (bramslow2004)",
    x = "Mean Loudness (Sones)",
    y = "Difference (Open-NL - AMT)",
    color = "Profile"
  )

ggsave("figures/Figure2_BlandAltman.png", plot = p, width = 8, height = 5, dpi = 300)
ggsave("manuscript_figures/Figure2_BlandAltman.png", plot = p, width = 8, height = 5, dpi = 300)
ggsave("reviewer_archive/Capstone_Final_Materials/figures/Figure2_BlandAltman.png", plot = p, width = 8, height = 5, dpi = 300)
