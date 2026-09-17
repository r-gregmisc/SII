#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

is_smoke <- Sys.getenv("JAAA_SMOKE") == "1"
out_dir <- if (is_smoke) "reproducibility_scripts/output/jaaa_audmod_smoke/" else "reproducibility_scripts/output/jaaa_audmod/"
write_run_metadata(out_dir)
parts_dir <- file.path(out_dir, "desens_parts")
dir.create(parts_dir, recursive = TRUE, showWarnings = FALSE)

library(parallel)
library(ggplot2)

profiles <- paste0("a", 1:7)
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
source("R/benchmark_targets.R")

lvl <- 65
input_speech <- build_opennl_speech(hl_freqs, lvl)

desens_scales <- seq(0.0, 1.0, by = 0.1)
floors <- c(0, -10)

if (is_smoke) {
  profiles <- profiles[1:2]
  desens_scales <- c(0.0, 1.0)
}
tasks <- expand.grid(Profile = profiles, Scale = desens_scales, Floor = floors, stringsAsFactors = FALSE)

run_cell <- function(p, s, f_val) {
  out_file <- file.path(parts_dir, sprintf("%s_scale%.1f_floor%d.csv", p, s, f_val))
  if (file.exists(out_file)) return(read.csv(out_file))
  
  start_time <- Sys.time()
  
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule=2)$y
  nal_loudness <- loudness_of(lvl, nal_gain_6, htl, loss)$total
  
  res <- tryCatch({
    open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, 
            cap_override = nal_loudness, vent_floor = f_val, desensitization_scale = s, optimize = TRUE)
  }, error=function(e) list(error = e$message))
  
  if (is.null(res$error)) {
    tgt <- build_target(hl_freqs, input_speech, htl, loss, res$gain, eval_level = lvl)
    sii_smoothed_s <- report_sii(tgt, "johnson2011_smoothed", desensitization_scale = s)
    sii_complete_s <- report_sii(tgt, "johnson2011_complete", desensitization_scale = s)
    sii_complete_full <- report_sii(tgt, "johnson2011_complete", desensitization_scale = 1.0)
    sii_ansi <- report_sii(tgt, "none", nal_ldf = FALSE, desensitization_scale = 1.0)
    ldn_val <- loudness_of(lvl, res$gain, htl, loss)$total
    
    df <- data.frame(
      Profile = p, Scale = s, vent_floor = f_val,
      sii_smoothed_s = sii_smoothed_s, sii_complete_s = sii_complete_s,
      sii_complete_full = sii_complete_full, sii_ansi = sii_ansi,
      Loudness = ldn_val,
      G250 = res$gain[1], G500 = res$gain[2], G1000 = res$gain[3],
      G2000 = res$gain[4], G4000 = res$gain[5], G8000 = res$gain[6], Error = NA
    )
  } else {
    df <- data.frame(
      Profile = p, Scale = s, vent_floor = f_val,
      sii_smoothed_s = NA, sii_complete_s = NA,
      sii_complete_full = NA, sii_ansi = NA,
      Loudness = NA,
      G250 = NA, G500 = NA, G1000 = NA,
      G2000 = NA, G4000 = NA, G8000 = NA, Error = res$error
    )
  }
  
  write.csv(df, out_file, row.names = FALSE)
  return(df)
}

cell_results <- mclapply(1:nrow(tasks), function(i) {
  run_cell(tasks$Profile[i], tasks$Scale[i], tasks$Floor[i])
}, mc.cores = 8)

df <- do.call(rbind, cell_results)

# Calculate Floor effect
floor_effects <- data.frame()
for (p in profiles) {
  for (s in desens_scales) {
    df_0 <- df[df$Profile == p & df$Scale == s & df$vent_floor == 0, ]
    df_10 <- df[df$Profile == p & df$Scale == s & df$vent_floor == -10, ]
    if (nrow(df_0) > 0 && nrow(df_10) > 0) {
      floor_effects <- rbind(floor_effects, data.frame(
        Profile = p, Scale = s,
        diff_smoothed_s = df_10$sii_smoothed_s - df_0$sii_smoothed_s,
        diff_complete_s = df_10$sii_complete_s - df_0$sii_complete_s,
        diff_complete_full = df_10$sii_complete_full - df_0$sii_complete_full,
        diff_ansi = df_10$sii_ansi - df_0$sii_ansi
      ))
    }
  }
}

write.csv(df, file.path(out_dir, "desens_sensitivity_raw.csv"), row.names=FALSE)
write.csv(floor_effects, file.path(out_dir, "desens_sensitivity_diffs.csv"), row.names=FALSE)

g <- ggplot(floor_effects, aes(x = Scale, y = diff_smoothed_s, color = Profile)) +
  geom_line(size = 1.2) + geom_point(size = 3) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
  labs(title = "SII Benefit of -10 dB LF Vent Floor vs 0 dB",
       subtitle = "By Desensitization Scale (Using sii_smoothed_s)",
       x = "Desensitization Factor (0 = None, 1.0 = Full)",
       y = "Δ SII (Open - Closed)") +
  theme_minimal()
ggsave(file.path(out_dir, "desens_sensitivity_floor_benefit.png"), plot=g, width=8, height=6, bg="white")
