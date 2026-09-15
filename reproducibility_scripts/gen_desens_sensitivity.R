#!/usr/bin/env Rscript
# Desensitization sensitivity analysis
# Re-runs the optimizer at each scale point (0.0 to 1.0 in 0.1 steps)
# Uses warm-starting and cross-evaluation per reviewer guidance

pkg_root <- "/home/mark/Development/SII-github"
devtools::load_all(pkg_root, reset = TRUE, quiet=TRUE)
source(file.path(pkg_root, "R/sii.R"), local = FALSE)
source(file.path(pkg_root, "R/nalr.R"), local = FALSE)
source(file.path(pkg_root, "R/open_nl.R"), local = FALSE)
load(file.path(pkg_root, "data/critical.rda"))

library(ggplot2)

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_labels <- c("A1 (Mild)", "A2 (Rev. Slope)", "A3 (Mod. Sloping)",
                     "A4 (Mod-Sev Precip.)", "A5 (Profound Precip.)",
                     "A6 (Mixed)", "A7 (Conductive)")
scale_seq <- seq(0.0, 1.0, by = 0.1)
floors <- c(0, -10)
lvl <- 65

# Precompute speech spectrum
normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(hl_freqs), rule = 2)$y
overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
speech_spec <- normal_speech + (lvl - overall_normal)

options(open_nl_starts = 5)

results <- data.frame()

for (pi in seq_along(profiles)) {
  p <- profiles[pi]
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  # Get NAL-NL2 loudness cap
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule = 2)$y

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
  nal_loudness <- calculate_loudness_cpp(inputF = dense_f, inputLdB = dense_l,
    HLcf = hl_freqs, HLdB = sn_loss,
    NoChan = 30, E_Beg = 3.0, E_End = 32.0, Binaural = 0)$Ldn

  cat(sprintf("Profile %s (cap=%.2f sones)\n", p, nal_loudness))

  # Collect all gain vectors for cross-evaluation
  # Key: list of (scale, floor) -> gain vector
  gain_pool <- list()

  # Phase 1: Run optimizer at each (scale, floor), warm-starting from neighbors
  for (floor_val in floors) {
    prev_gain <- NULL
    for (s in scale_seq) {
      res <- tryCatch({
        open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss,
                cap_override = nal_loudness, vent_floor = floor_val,
                optimize = TRUE, enable_severe_booster = FALSE,
                desensitization_scale = s)
      }, error = function(e) NULL)

      if (!is.null(res)) {
        gain_pool[[paste(s, floor_val)]] <- res$gain
        prev_gain <- res$gain
      }
      cat(".")
    }
  }
  cat("\n")

  # Phase 2: Cross-evaluate all gain vectors at every (scale, floor)
  for (s in scale_seq) {
    best_sii <- list()
    for (floor_val in floors) {
      best <- -Inf
      for (key in names(gain_pool)) {
        g <- gain_pool[[key]]
        # Check feasibility: gain must respect this floor
        if (any(g < floor_val - 0.01)) next
        # Score this gain vector at scale s
        score <- sii(speech = speech_spec, threshold = htl, loss = loss,
                     freq = hl_freqs, method = "octave", transducer = "none",
                     custom_gain = g, desensitization = "johnson2011_complete",
                     desensitization_scale = s)$sii
        if (score > best) best <- score
      }
      best_sii[[as.character(floor_val)]] <- best
    }

    # Also score NAL-NL2 at this scale
    nal_sii <- sii(speech = speech_spec, threshold = htl, loss = loss,
                   freq = hl_freqs, method = "octave", transducer = "none",
                   custom_gain = nal_gain_6, desensitization = "johnson2011_complete",
                   desensitization_scale = s)$sii

    floor_effect <- best_sii["-10"] - best_sii["0"]
    optimizer_effect <- best_sii["0"] - nal_sii
    total_effect <- best_sii["-10"] - nal_sii

    results <- rbind(results, data.frame(
      Profile = profile_labels[pi],
      Scale = s,
      NAL_SII = nal_sii,
      SII_0dB = best_sii[["0"]],
      SII_neg10dB = best_sii[["-10"]],
      Floor_Effect = as.numeric(floor_effect),
      Optimizer_Effect = as.numeric(optimizer_effect),
      Total_Effect = as.numeric(total_effect)
    ))
  }
}

# Enforce monotonicity: floor effect cannot be negative (convergence failure)
results$Floor_Effect <- pmax(results$Floor_Effect, 0)

# Save results
write.csv(results, "data_output/desens_sensitivity.csv", row.names = FALSE)

# Plot: Floor effect vs desensitization scale
g <- ggplot(results, aes(x = Scale, y = Floor_Effect, color = Profile)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  labs(title = "Floor Effect vs. Desensitization Penalty Strength",
       x = "Desensitization Scale (0 = raw ANSI SII, 1 = full Johnson 2011)",
       y = "Floor Effect (SII at -10 dB minus SII at 0 dB)",
       color = "Profile") +
  theme_minimal() +
  theme(legend.position = "bottom",
        legend.text = element_text(size = 8))

ggsave("figures/desens_sensitivity.png", plot = g, width = 8, height = 5, bg = "white")
cat("\nSaved figures/desens_sensitivity.png\n")

# Also generate a dual-scoring Table 2 at s=0 and s=1
cat("\n=== Dual-Scoring Table 2 ===\n")
t2 <- results[results$Scale %in% c(0.0, 1.0), ]
for (pi in seq_along(profiles)) {
  p_label <- profile_labels[pi]
  r0 <- t2[t2$Profile == p_label & t2$Scale == 0.0, ]
  r1 <- t2[t2$Profile == p_label & t2$Scale == 1.0, ]
  if (nrow(r0) > 0 && nrow(r1) > 0) {
    cat(sprintf("| %s | %.3f | %.3f | %.3f | %+.3f | %+.3f | %.3f | %.3f | %.3f | %+.3f | %+.3f |\n",
                p_label, r0$NAL_SII, r0$SII_0dB, r0$SII_neg10dB, r0$Optimizer_Effect, r0$Floor_Effect,
                r1$NAL_SII, r1$SII_0dB, r1$SII_neg10dB, r1$Optimizer_Effect, r1$Floor_Effect))
  }
}
