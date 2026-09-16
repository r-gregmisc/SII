suppressWarnings(rm(list = intersect(ls(envir = .GlobalEnv), c("open_nl", "sii", "calculate_loudness", "calculate_open_nl_gain")), envir = .GlobalEnv))
devtools::load_all(".", reset = TRUE)
source("R/benchmark_targets.R")

options(open_nl_maxit = 150, open_nl_starts = 1)

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c("Normal", paste0("a", 1:7))
levels <- c(50, 65, 80)
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)

results <- data.frame()

get_legacy_cap <- function(lvl, threshold, loss) {
  sn_octaves <- approx(x = log10(hl_freqs), y = (threshold - loss), xout = log10(c(500, 1000, 2000, 4000)), rule = 2)$y
  pta_sn_local <- mean(sn_octaves, na.rm = TRUE)
  abg_octaves <- approx(x = log10(hl_freqs), y = loss, xout = log10(c(500, 1000, 2000, 4000)), rule = 2)$y
  pta_abg_local <- mean(abg_octaves, na.rm = TRUE)
  
  pta_knots <- c(10, 32.5, 52.5, 72.5, 90)
  if (abs(lvl - 50) < 0.1) {
    cap_knots <- c(1.5, 1.0, 0.8, 1.2, 1.2)
  } else if (abs(lvl - 80) < 0.1) {
    cap_knots <- c(20.0, 12.0, 10.0, 15.0, 14.0)
  } else {
    cap_knots <- c(7.0, 4.5, 4.0, 6.5, 6.0)
  }
  
  dynamic_cap <- approx(x = pta_knots, y = cap_knots, xout = pta_sn_local, rule = 2)$y
  
  htl <- threshold
  low_hf_diff <- mean(htl[1:2]) - mean(htl[5:6])
  if (low_hf_diff > 10 && lvl >= 75) {
    dynamic_cap <- dynamic_cap - (low_hf_diff * 0.10)
  }
  if (pta_abg_local > 0) {
    if (lvl >= 75) {
      dynamic_cap <- dynamic_cap - (pta_abg_local * 0.25)
    } else {
      dynamic_cap <- dynamic_cap + (pta_abg_local * 0.10)
    }
  }
  dynamic_cap
}

for (p in profiles) {
  for (lvl in levels) {
    input_speech <- ltass_65 + (lvl - 65)
    if (p == "Normal") {
      threshold <- rep(0, 6)
      loss <- rep(0, 6)
      res_nal <- list(gain = rep(0, 6), threshold = threshold, loss = loss, freq = hl_freqs, overall_level = lvl)
      nal_ldn <- calculate_loudness(res_nal)$total
      
      results <- rbind(results, data.frame(
        profile = p, level = lvl,
        cap_legacy = get_legacy_cap(lvl, threshold, loss),
        cap_normal = normal_speech_loudness(lvl),
        gain_24_legacy = 0, gain_24_normal = 0,
        ldn_nal = nal_ldn,
        ldn_legacy = nal_ldn, ldn_normal = nal_ldn,
        binding_legacy = (nal_ldn >= 0.99 * get_legacy_cap(lvl, threshold, loss)),
        binding_normal = (nal_ldn >= 0.99 * normal_speech_loudness(lvl)),
        sii_legacy = NA, sii_normal = NA
      ))
    } else {
      target_data <- jd2011_targets[[p]]
      threshold <- target_data$threshold
      loss <- rep(0, 6)
      if (p == "a6") loss <- rep(30, 6)
      if (p == "a7") loss <- rep(50, 6)
      
      gain_nal <- get_nalnl2_v2_target(p, "NAL-NL2", target_freqs = hl_freqs, level = lvl)
      res_nal <- list(gain = gain_nal, threshold = threshold, loss = loss, freq = hl_freqs, overall_level = lvl)
      nal_ldn <- calculate_loudness(res_nal)$total
      
      presc_leg <- open_nl(speech = lvl, threshold = threshold, freq = hl_freqs, loss = loss, cap_rule = "legacy")
      ldn_leg <- calculate_loudness(presc_leg)$total
      sii_leg <- sii(speech = input_speech, threshold = threshold, loss = loss, freq = hl_freqs, method = "octave", transducer = "none", custom_gain = presc_leg$gain, desensitization = "johnson2011_complete")$sii
      gain24_leg <- mean(presc_leg$gain[4:5])
      
      presc_norm <- open_nl(speech = lvl, threshold = threshold, freq = hl_freqs, loss = loss, cap_rule = "normal")
      ldn_norm <- calculate_loudness(presc_norm)$total
      sii_norm <- sii(speech = input_speech, threshold = threshold, loss = loss, freq = hl_freqs, method = "octave", transducer = "none", custom_gain = presc_norm$gain, desensitization = "johnson2011_complete")$sii
      gain24_norm <- mean(presc_norm$gain[4:5])
      
      cap_leg <- get_legacy_cap(lvl, threshold, loss)
      cap_norm <- normal_speech_loudness(lvl)
      
      results <- rbind(results, data.frame(
        profile = p, level = lvl,
        cap_legacy = cap_leg,
        cap_normal = cap_norm,
        gain_24_legacy = gain24_leg, gain_24_normal = gain24_norm,
        ldn_nal = nal_ldn,
        ldn_legacy = ldn_leg, ldn_normal = ldn_norm,
        binding_legacy = (ldn_leg >= 0.99 * cap_leg),
        binding_normal = (ldn_norm >= 0.99 * cap_norm),
        sii_legacy = sii_leg, sii_normal = sii_norm
      ))
    }
  }
}
write.csv(results, "cap_rule_comparison.csv", row.names=FALSE)
cat("Wrote cap_rule_comparison.csv\n")
print(results)
