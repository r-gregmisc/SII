library(dplyr)
library(ggplot2)
library(reshape2)
library(parallel)
suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness", "calculate_open_nl_gain")), envir = .GlobalEnv))
devtools::load_all(".", reset = TRUE, quiet=TRUE)
source("R/benchmark_targets.R")

cat("Regenerating Sensitivity Figure 4 and ANOVA decomposition...\n")

anchors <- seq(0.3, 0.6, length.out=4)
triggers <- seq(65, 85, length.out=4)
bypasses <- seq(60, 80, length.out=4)
floors <- seq(-20, 0, length.out=4)
profiles <- c("a2", "a4", "a5")

grid <- expand.grid(Profile = profiles, anc = anchors, trig = triggers, byp = bypasses, flr = floors, stringsAsFactors=FALSE)
cat("Running", nrow(grid), "permutations across 8 cores...\n")
cat("NOTE: Progress is being written to 'manuscript_figures/sensitivity_progress.csv' in real time.\n")
cat("To watch progress, open a second terminal and run:\n  tail -f manuscript_figures/sensitivity_progress.csv\n\n")

csv_file <- "manuscript_figures/sensitivity_progress.csv"
cat("Profile,Anchor,Trigger,Bypass,Floor,SII,Sones\n", file=csv_file)

invisible(mclapply(1:nrow(grid), function(idx) {
  p <- grid$Profile[idx]
  anc <- grid$anc[idx]
  trig <- grid$trig[idx]
  byp <- grid$byp[idx]
  flr <- grid$flr[idx]
  
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  presc <- open_nl(
    speech = 65, threshold = target_data$threshold, loss = rep(0, 6), freq = freqs, 
    optimize = TRUE, optim_method = "Nelder-Mead", enable_severe_booster = TRUE,
    booster_onset = 60,
    anchor = anc, slope_trigger = trig, bypass_pta = byp, rs_floor = flr
  )
  
  obj <- sii(speech="normal", threshold=target_data$threshold, freq=freqs, prescription=presc, interpolate=TRUE)
  s_val <- calculate_loudness(presc)$total
  
  # Write immediately to the CSV so you can track progress
  cat(sprintf("%s,%f,%f,%f,%f,%f,%f\n", toupper(p), anc, trig, byp, flr, obj$sii, s_val), file=csv_file, append=TRUE)
  
  # Also print to stderr so it shows up in the console
  cat(sprintf("Finished %s permutation...\n", toupper(p)), file=stderr())
}, mc.cores = 8))

df <- read.csv(csv_file, stringsAsFactors=FALSE)

cat("\n--- ANOVA Variance Decomposition & Elasticities ---\n")
for (p in unique(df$Profile)) {
  sub_df <- df[df$Profile == p, ]
  
  cat(sprintf("\nProfile %s Bounds:\n", p))
  cat(sprintf("  SII: median = %.2f, min = %.2f, max = %.2f\n", median(sub_df$SII), min(sub_df$SII), max(sub_df$SII)))
  cat(sprintf("  Sones: median = %.2f, min = %.2f, max = %.2f\n", median(sub_df$Sones), min(sub_df$Sones), max(sub_df$Sones)))
  
  sub_df <- sub_df %>%
    mutate(
      norm_anc = (Anchor - min(Anchor))/(max(Anchor) - min(Anchor)),
      norm_trig = (Trigger - min(Trigger))/(max(Trigger) - min(Trigger)),
      norm_byp = (Bypass - min(Bypass))/(max(Bypass) - min(Bypass)),
      norm_flr = (Floor - min(Floor))/(max(Floor) - min(Floor))
    )
    
  mod <- aov(Sones ~ norm_anc + norm_trig + norm_byp + norm_flr, data=sub_df)
  ss <- summary(mod)[[1]]$`Sum Sq`
  pct_var <- ss / sum(ss) * 100
  
  cat(sprintf("  Dominant Variance Factor (Sones): %s (%.1f%%)\n", c("Anchor", "Trigger", "Bypass", "Floor")[which.max(pct_var)], max(pct_var)))
}

df_melt <- melt(df[, c("Profile", "SII", "Sones")], id.vars="Profile")
p4 <- ggplot(df_melt, aes(x=Profile, y=value, fill=Profile)) +
  geom_boxplot() + facet_wrap(~variable, scales="free_y") +
  theme_minimal() + theme(legend.position="none")
ggsave("manuscript_figures/Figure4_Sensitivity.png", p4, width=8, height=5, dpi=300)
