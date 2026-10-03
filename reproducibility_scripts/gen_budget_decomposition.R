#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

write_run_metadata("reproducibility_scripts/output/jaaa_audmod")
out_file <- "reproducibility_scripts/output/jaaa_audmod/table1_budget_decomposition.csv"

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c("Normal", paste0("a", 1:7))
levels <- c(50, 65, 80)

# load target definitions for jd2011_targets
source("R/benchmark_targets.R")

results <- data.frame()

for (p in profiles) {
  for (lvl in levels) {
    if (p == "Normal") {
        threshold <- rep(0, 6)
        loss <- rep(0, 6)
    } else {
        threshold <- jd2011_targets[[p]]$threshold
        loss <- rep(0, 6)
        if (p == "a6") loss <- rep(30, 6)
        if (p == "a7") loss <- rep(50, 6)
    }
    
    L0 <- loudness_of(lvl, rep(0, 6), threshold, loss)$total
    Lcap <- lcap(lvl)
    
    results <- rbind(results, data.frame(
        Profile = p,
        Level = lvl,
        L0 = L0,
        Lcap = Lcap,
        Budget = Lcap - L0,
        Ratio = ifelse(Lcap > 0, L0 / Lcap, NA)
    ))
  }
}
write.csv(results, out_file, row.names=FALSE)
cat(sprintf("Wrote %s\n", out_file))
print(results)
