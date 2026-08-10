library(ggplot2)
library(dplyr)
library(tidyr)
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
for (f in r_files) source(f)

freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- list(
  "A1 (Mild)" = c(20, 25, 40, 60, 75, 80),
  "A2 (Moderate Rev)" = c(50, 45, 40, 35, 35, 40),
  "A3 (Moderate Sloping)" = c(30, 35, 45, 65, 80, 85),
  "A4 (Severe Steep)" = c(40, 45, 55, 70, 80, 80),
  "A5 (Profound Steep)" = c(10, 10, 20, 60, 80, 100),
  "A6 (Mixed)" = c(50, 50, 55, 65, 80, 85),
  "A7 (Conductive)" = c(40, 40, 45, 55, 60, 60)
)

results <- data.frame()

for (pname in names(profiles)) {
  p <- profiles[[pname]]
  abg <- if(grepl("A6", pname)) rep(30, length(p)) else if(grepl("A7", pname)) rep(50, length(p)) else rep(0, length(p))
  
  # Heuristic (Seed)
  t_seed <- open_nl(65, threshold = p, freq = freqs, loss = abg, optimize = FALSE)
  res_seed <- sii(speech = t_seed$speech, noise = rep(-50, length(freqs)), threshold = p, loss = abg, freq = freqs, prescription = t_seed, interpolate = TRUE)
  sii_seed <- res_seed$sii
  sones_seed <- calculate_loudness(res_seed)
  
  # Optimized
  t_opt <- open_nl(65, threshold = p, freq = freqs, loss = abg, optimize = TRUE, loudness_cap = 20.0)
  res_opt <- sii(speech = t_opt$speech, noise = rep(-50, length(freqs)), threshold = p, loss = abg, freq = freqs, prescription = t_opt, interpolate = TRUE)
  sii_opt <- res_opt$sii
  sones_opt <- calculate_loudness(res_opt)
  
  results <- rbind(results, data.frame(
    Profile = pname,
    Type = "Heuristic Seed",
    SII = sii_seed,
    Sones = sones_seed
  ))
  
  results <- rbind(results, data.frame(
    Profile = pname,
    Type = "Optimized",
    SII = sii_opt,
    Sones = sones_opt
  ))
}

# Plot
p_sii <- ggplot(results, aes(x = Profile, y = SII, fill = Type)) +
  geom_bar(stat = "identity", position = "dodge") +
  theme_minimal() +
  coord_flip() +
  labs(title = "SII Maximization: Seed vs Optimized", x = "Audiometric Profile", y = "Speech Intelligibility Index (SII)")

p_sones <- ggplot(results, aes(x = Profile, y = Sones, fill = Type)) +
  geom_bar(stat = "identity", position = "dodge") +
  geom_hline(yintercept = 20.0, linetype = "dashed", color = "red") +
  theme_minimal() +
  coord_flip() +
  labs(title = "Loudness Constraint Verification", x = "Audiometric Profile", y = "Physiological Loudness (Sones)", subtitle = "Red dashed line indicates 20.0 sone safety limit")

ggsave("Figure1_Optimization_SII.png", p_sii, width = 8, height = 5)
ggsave("Figure2_Optimization_Loudness.png", p_sones, width = 8, height = 5)

write.csv(results, "optimization_results.csv", row.names = FALSE)
