#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

write_run_metadata("reproducibility_scripts/output/jaaa_audmod")
out_dir <- "reproducibility_scripts/output/jaaa_audmod/"

library(ggplot2)

profiles <- c("a4", "a5")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
source("R/benchmark_targets.R")

lvl <- 65
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
input_speech <- ltass_65 + (lvl - 65)

run_grid <- function(p) {
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  
  cap_seq <- seq(4.0, 14.0, by = 0.25)
  floor_seq <- c(0, -2.5, -5.0, -7.5, -10.0, -12.5, -15.0)
  
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule=2)$y
  nal_loudness <- loudness_of(lvl, nal_gain_6, htl, loss)$total
  
  norm_cap <- lcap(lvl)
  
  results <- list()
  
  # Start from tightest floor (0) and loose cap (14) then go tighter cap?
  # Or start tightest cap (4) and move up.
  for (f_val in floor_seq) {
    prev_gain <- NULL
    for (c_val in cap_seq) {
      res <- tryCatch({
        open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss,
                cap_override = c_val, vent_floor = f_val, 
                constraint_gain = prev_gain, optimize = TRUE)
      }, error=function(e) NULL)
      
      if (!is.null(res)) {
        prev_gain <- res$gain
        hf_gain <- mean(res$gain[4:5])
        sii_val <- sii(speech=input_speech, threshold=htl, loss=loss, freq=hl_freqs, method="octave", transducer="none", custom_gain=res$gain, desensitization="johnson2011_complete")$sii
        results[[length(results) + 1]] <- c(c_val, f_val, hf_gain, sii_val)
      } else {
        results[[length(results) + 1]] <- c(c_val, f_val, NA, NA)
      }
    }
  }
  
  df <- data.frame(do.call(rbind, results))
  colnames(df) <- c("L_cap", "vent_floor", "HF_Gain", "SII")
  df$Profile <- p
  
  for (f_val in floor_seq) {
     sub_df <- df[df$vent_floor == f_val, ]
     for (i in 2:nrow(sub_df)) {
        if (!is.na(sub_df$SII[i]) && !is.na(sub_df$SII[i-1]) && sub_df$SII[i] < sub_df$SII[i-1] - 1e-4) {
            cat(sprintf("Warning: Non-monotonic SII for %s at floor %.1f: Cap %.2f -> %.2f (SII %.4f -> %.4f)\n", p, f_val, sub_df$L_cap[i-1], sub_df$L_cap[i], sub_df$SII[i-1], sub_df$SII[i]))
        }
     }
  }
  
  g1 <- ggplot(df, aes(x = L_cap, y = vent_floor, z = HF_Gain)) +
    geom_contour_filled() +
    geom_point(aes(x = nal_loudness, y = 0), color="red", size=4, shape=4) +
    geom_vline(xintercept = norm_cap, linetype="dashed", color="blue") +
    annotate("text", x = nal_loudness, y = 0.5, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("HF Gain Map -", toupper(p)), x = "Loudness Cap (sones)", y = "LF Floor (dB)", fill = "2-4 kHz gain of SII-optimal solution") +
    theme_minimal()
  ggsave(file.path(out_dir, sprintf("feasibility_hf_%s.png", p)), plot=g1, width=7, height=5, bg="white")
  
  g2 <- ggplot(df, aes(x = L_cap, y = vent_floor, z = SII)) +
    geom_contour_filled() +
    geom_point(aes(x = nal_loudness, y = 0), color="red", size=4, shape=4) +
    geom_vline(xintercept = norm_cap, linetype="dashed", color="blue") +
    annotate("text", x = nal_loudness, y = 0.5, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("SII Map -", toupper(p)), x = "Loudness Cap (sones)", y = "LF Floor (dB)", fill = "SII") +
    theme_minimal()
  ggsave(file.path(out_dir, sprintf("feasibility_sii_%s.png", p)), plot=g2, width=7, height=5, bg="white")
  
  return(df)
}

all_grids <- list()
for (p in profiles) {
  cat("Running grid for profile", p, "\n")
  all_grids[[p]] <- run_grid(p)
}

grid_df <- do.call(rbind, all_grids)
write.csv(grid_df, file.path(out_dir, "feasibility_grid.csv"), row.names=FALSE)
