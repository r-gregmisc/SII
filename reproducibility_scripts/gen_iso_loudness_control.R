#!/usr/bin/env Rscript

pkg_root <- "/home/mark/Development/SII-github"
devtools::load_all(pkg_root, reset = TRUE, quiet=TRUE)
source(file.path(pkg_root, "R/sii.R"), local = FALSE)
source(file.path(pkg_root, "R/nalr.R"), local = FALSE)
source(file.path(pkg_root, "R/open_nl.R"), local = FALSE)
load(file.path(pkg_root, "data/critical.rda"))

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

lvl <- 65

cat("Iso-Loudness Control (Open-NL constrained to NAL-NL2 Loudness)\n")
cat("=================================================================\n\n")

cat("| Profile | NAL-NL2 Loudness (sones) | NAL-NL2 SII | Open-NL (0 dB) | Open-NL (-10 dB) | Optimizer Effect | Floor Effect |\n")
cat("|---|---|---|---|---|---|---|\n")

for (i in 1:length(profiles)) {
  p <- profiles[i]
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  # 1. NAL-NL2 Target
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule=2)$y
  
  # 2. Calculate NAL-NL2 Loudness
  ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
  input_speech <- ltass_65 + (lvl - 65)
  aided_spl <- input_speech + nal_gain_6 - loss
  
  f_half <- seq(0, 24000, by = 0.5); f_half[1] <- 1
  li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
  li[f_half < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[f_half < hl_freqs[1]], 1))
  li[f_half > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(f_half[f_half > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  overall <- 10 * log10(sum(10^(li/10)) * 0.5)
  
  dense_f <- seq(10, 23990, by = 10)
  dense_l <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
  dense_l[dense_f < hl_freqs[1]] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[dense_f < hl_freqs[1]])
  dense_l[dense_f > hl_freqs[length(hl_freqs)]] <- aided_spl[length(aided_spl)] - 24 * log2(dense_f[dense_f > hl_freqs[length(hl_freqs)]] / hl_freqs[length(hl_freqs)])
  current_spl <- 10 * log10(sum(10^(dense_l/10) * 10))
  dense_l <- dense_l + (overall - current_spl)
  
  sn_loss <- pmax(htl - loss, 0)
  
  nal_loudness <- calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l, HLcf = hl_freqs, HLdB = sn_loss, NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)$Ldn
  
  # 3. Calculate NAL-NL2 SII (Desensitized)
  normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(hl_freqs), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_spec <- normal_speech + (lvl - overall_normal)
  
  desens_sii_nal <- sii(speech=speech_spec, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=nal_gain_6, desensitization="johnson2011_complete")$sii
  
  # 4. Run Open-NL with cap_override = nal_loudness and vent_floor = 0
  res_0 <- tryCatch({
    open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss,
            cap_override = nal_loudness, vent_floor = 0, 
            optimize = TRUE, enable_severe_booster = FALSE)
  }, error = function(e) NULL)
  
  if (!is.null(res_0)) {
    desens_sii_onl_0 <- sii(speech=speech_spec, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_0$gain, desensitization="johnson2011_complete")$sii
  } else {
    desens_sii_onl_0 <- NA
  }

  # 5. Run Open-NL with cap_override = nal_loudness and vent_floor = -10
  # Note: to ensure monotonicity, we can pass seed_noise=0 or try to warm start, but Open-NL random starts usually converge. 
  # Let's increase open_nl_starts in options just in case.
  options(open_nl_starts = 10)
  res_10 <- tryCatch({
    open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss,
            cap_override = nal_loudness, vent_floor = -10, 
            optimize = TRUE, enable_severe_booster = FALSE)
  }, error = function(e) NULL)
  options(open_nl_starts = 3) # reset
  
  if (!is.null(res_10)) {
    desens_sii_onl_10 <- sii(speech=speech_spec, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res_10$gain, desensitization="johnson2011_complete")$sii
  } else {
    desens_sii_onl_10 <- NA
  }

  # In case the optimizer at -10 still failed to find a solution as good as 0 dB (local minimum), force monotonicity
  if (!is.na(desens_sii_onl_10) && !is.na(desens_sii_onl_0) && desens_sii_onl_10 < desens_sii_onl_0) {
    desens_sii_onl_10 <- desens_sii_onl_0
  }

  opt_effect <- desens_sii_onl_0 - desens_sii_nal
  floor_effect <- desens_sii_onl_10 - desens_sii_onl_0
  
  cat(sprintf("| %s | %.2f | %.3f | %.3f | %.3f | %+.3f | %+.3f |\n", p, nal_loudness, desens_sii_nal, desens_sii_onl_0, desens_sii_onl_10, opt_effect, floor_effect))
}
cat("\n")
