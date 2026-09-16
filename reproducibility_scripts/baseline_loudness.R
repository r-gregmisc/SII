devtools::load_all()

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ltass_65  <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
levels <- c(50, 65, 80)
profiles <- c("Normal", "a1", "a2", "a3", "a4", "a5")

# Load targets

results_total <- data.frame()
results_nprime <- data.frame()

for (prof in profiles) {
  if (prof == "Normal") {
    htl <- rep(0, 6)
  } else {
    htl <- jd2011_targets[[prof]]$threshold
  }
  
  for (lvl in levels) {
    input_speech <- ltass_65 + (lvl - 65)
    aided_spl <- input_speech
    
    dense_f <- seq(10, 23990, by = 10)
    dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y

    dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
    dense_l[dense_f > hl_freqs[6]] <- aided_spl[6] - 24 * log2(dense_f[dense_f > hl_freqs[6]] / hl_freqs[6])

    res <- calculate_loudness_cpp(
      inputF = dense_f, 
      inputLdB = dense_l,
      HLcf = hl_freqs, 
      HLdB = htl
    )
    
    results_total <- rbind(results_total, data.frame(
      profile = prof,
      level = lvl,
      Ldn = res$Ldn
    ))
    
    tmp_nprime <- data.frame(
      profile = prof,
      level = lvl,
      channel = 1:length(res$N_prime),
      CF = res$CF,
      Cam = res$Cam,
      N_prime = res$N_prime
    )
    results_nprime <- rbind(results_nprime, tmp_nprime)
  }
}

write.csv(results_total, "baseline_loudness_before.csv", row.names=FALSE)
write.csv(results_nprime, "baseline_nprime_before.csv", row.names=FALSE)

cat("baseline_loudness_before.csv:\n")
print(head(results_total))
cat("\nbaseline_nprime_before.csv:\n")
print(head(results_nprime))
