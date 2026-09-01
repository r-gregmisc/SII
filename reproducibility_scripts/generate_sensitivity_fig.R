library(SII)
library(ggplot2)
library(reshape2)
library(parallel)
source("R/benchmark_targets.R")

cat("Regenerating Sensitivity Figure 4 using parallel processing...\n")

anchors <- seq(0.3, 0.6, length.out=4)
triggers <- seq(65, 85, length.out=4)
bypasses <- seq(60, 80, length.out=4)
floors <- seq(-20, 0, length.out=4)

profiles <- c("a2", "a4", "a5")

grid <- expand.grid(Profile = profiles, anc = anchors, trig = triggers, byp = bypasses, flr = floors, stringsAsFactors=FALSE)

cat("Running", nrow(grid), "permutations across 8 CPU cores...\n")

csv_file <- "manuscript_figures/sensitivity_progress.csv"
cat("Profile,SII,Sones\n", file=csv_file)

invisible(mclapply(1:nrow(grid), function(idx) {
  p <- grid$Profile[idx]
  p_name <- toupper(p)
  anc <- grid$anc[idx]
  trig <- grid$trig[idx]
  byp <- grid$byp[idx]
  flr <- grid$flr[idx]
  
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  
  presc <- open_nl(
    speech = 65, 
    threshold = threshold, 
    loss = loss,
    freq = freqs, 
    optimize = TRUE,
    optim_method = "Nelder-Mead",
    enable_severe_booster = TRUE,
    booster_onset = trig,
    anchor = anc,
    slope_trigger = trig,
    bypass_pta = byp,
    rs_floor = flr
  )
  
  obj <- sii(speech="normal", threshold=threshold, freq=freqs, prescription=presc, interpolate=TRUE)
  s_val <- calculate_loudness(presc)$total
  
  cat(sprintf("Completed %s permutation %d/%d\n", p_name, idx, nrow(grid)), file=stderr())
  cat(sprintf("%s,%f,%f\n", p_name, obj$sii, s_val), file=csv_file, append=TRUE)
}, mc.cores = 12))

df <- read.csv(csv_file, stringsAsFactors=FALSE)
df_melt <- melt(df, id.vars="Profile")

p4 <- ggplot(df_melt, aes(x=Profile, y=value, fill=Profile)) +
  geom_boxplot() +
  facet_wrap(~variable, scales="free_y") +
  theme_minimal(base_size=14) +
  labs(title="Figure 4: Parameter Sensitivity Analysis", 
       subtitle="Distribution of Objective Function Outcomes (256 Permutations)",
       y="Value", x="Clinical Profile") +
  theme(legend.position="none", plot.title=element_text(face="bold"))

ggsave("manuscript_figures/Figure4_Sensitivity.png", p4, width=8, height=5, dpi=300)
cat("Done! Plot saved to manuscript_figures/Figure4_Sensitivity.png\n")
