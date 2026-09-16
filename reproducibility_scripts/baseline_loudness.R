#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

write_run_metadata("reproducibility_scripts/output/jaaa_audmod")
out_dir <- "reproducibility_scripts/output/jaaa_audmod/"

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
levels <- c(50, 65, 80)
profiles <- c("Normal", paste0("a", 1:7))

source("R/benchmark_targets.R")

results_total <- data.frame()
results_nprime <- data.frame()

for (prof in profiles) {
  if (prof == "Normal") {
    htl <- rep(0, 6)
    loss <- rep(0, 6)
  } else {
    htl <- jd2011_targets[[prof]]$threshold
    loss <- rep(0, 6)
    if (prof == "a6") loss <- rep(30, 6)
    if (prof == "a7") loss <- rep(50, 6)
  }
  
  for (lvl in levels) {
    res <- loudness_of(lvl, rep(0, 6), htl, loss)
    
    results_total <- rbind(results_total, data.frame(
      profile = prof,
      level = lvl,
      Ldn = res$total
    ))
    
    # Wait, the AMT ported list object might have slightly different names
    # audmod_loudness_cpp returns E_Vector and N_prime according to user previous requests.
    # But in calculate_loudness_audmod, we return:
    # list(total = ..., specific = N_prime, E_Vector = E_Vector, fc = fc)
    # Let's ensure this matches the list returned.
    
    tmp_nprime <- data.frame(
      profile = prof,
      level = lvl,
      channel = 1:length(res$specific),
      CF = res$fc,
      E = res$E,
      N_prime = res$specific
    )
    results_nprime <- rbind(results_nprime, tmp_nprime)
  }
}

write.csv(results_total, file.path(out_dir, "baseline_loudness_audmod.csv"), row.names=FALSE)
write.csv(results_nprime, file.path(out_dir, "baseline_nprime_audmod.csv"), row.names=FALSE)
