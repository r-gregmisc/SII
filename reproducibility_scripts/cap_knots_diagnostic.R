suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness", "calculate_open_nl_gain")), envir = .GlobalEnv))
devtools::load_all(".", reset = TRUE)
source("R/benchmark_targets.R")

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c("Normal", paste0("a", 1:7))
levels <- c(50, 65, 80)

results <- data.frame()

for (p in profiles) {
  for (lvl in levels) {
    if (p == "Normal") {
      threshold <- rep(0, 6)
      loss <- rep(0, 6)
      gain_tgt <- rep(0, 6)
    } else {
      target_data <- jd2011_targets[[p]]
      threshold <- target_data$threshold
      loss <- rep(0, 6)
      if (p == "a6") loss <- rep(30, 6)
      if (p == "a7") loss <- rep(50, 6)
      gain_tgt <- get_nalnl2_v2_target(p, "NAL-NL2", target_freqs = hl_freqs, level = lvl)
    }
    
    # 1. PTA and Cap Logic exactly from open_nl.R
    sn_octaves <- approx(x = log10(hl_freqs), y = (threshold - loss), xout = log10(c(500, 1000, 2000, 4000)), rule = 2)$y
    pta_sn_local <- mean(sn_octaves, na.rm = TRUE)
    
    abg_octaves <- approx(x = log10(hl_freqs), y = loss, xout = log10(c(500, 1000, 2000, 4000)), rule = 2)$y
    pta_abg_local <- mean(abg_octaves, na.rm = TRUE)
    
    pta_knots <- c(10, 32.5, 52.5, 72.5, 90)
    if (abs(lvl - 50) < 0.1) {
      cap_knots <- c(1.5, 1.0, 0.8, 1.2, 1.2)
    } else if (abs(lvl - 80) < 0.1) {
      cap_knots <- c(20.0, 12.0, 10.0, 15.0, 14.0)
    } else { # 65 dB
      cap_knots <- c(7.0, 4.5, 4.0, 6.5, 6.0)
    }
    
    dynamic_cap <- approx(x = pta_knots, y = cap_knots, xout = pta_sn_local, rule = 2)$y
    
    # Reverse slope adjustment
    htl <- threshold # Already at hl_freqs
    low_hf_diff <- mean(htl[1:2]) - mean(htl[5:6])
    if (low_hf_diff > 10 && lvl >= 75) {
      dynamic_cap <- dynamic_cap - (low_hf_diff * 0.10)
    }
    
    # ABG adjustment
    if (pta_abg_local > 0) {
      if (lvl >= 75) {
        dynamic_cap <- dynamic_cap - (pta_abg_local * 0.25)
      } else {
        dynamic_cap <- dynamic_cap + (pta_abg_local * 0.10)
      }
    }
    
    # 2. Compute Loudness (Spectrum Construction)
    ltass_65  <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
    input_speech <- ltass_65 + (lvl - 65)
    aided_spl    <- input_speech + gain_tgt - loss

    dense_f <- seq(10, 23990, by = 10)
    dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
    dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
    dense_l[dense_f > hl_freqs[6]] <- aided_spl[6] - 24 * log2(dense_f[dense_f > hl_freqs[6]] / hl_freqs[6])

    sn_loss  <- pmax(threshold - loss, 0)
    
    # Old engine
    res_old <- calculate_loudness_cpp(
      inputF = dense_f, 
      inputLdB = dense_l,
      HLcf = hl_freqs, 
      HLdB = sn_loss
    )
    nal_old <- res_old$Ldn
    
    # New engine (via R wrapper)
    tgt <- list(gain = gain_tgt, threshold = threshold, loss = loss, freq = hl_freqs, overall_level = lvl)
    nal_new <- calculate_loudness(tgt)$total
    
    results <- rbind(results, data.frame(
      profile = p,
      level = lvl,
      PTA_sn = pta_sn_local,
      nal_old = nal_old,
      nal_new = nal_new,
      cap_current = dynamic_cap,
      ratio_old = dynamic_cap / nal_old,
      ratio_new = dynamic_cap / nal_new
    ))
  }
}

write.csv(results, "cap_knots_diagnostic.csv", row.names = FALSE)
cat("Wrote cap_knots_diagnostic.csv\n")
print(results)
