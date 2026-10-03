#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")

is_smoke <- Sys.getenv("JAAA_SMOKE") == "1"
out_dir <- if (is_smoke) "reproducibility_scripts/output/jaaa_audmod_smoke/" else "reproducibility_scripts/output/jaaa_audmod/"
write_run_metadata(out_dir)
parts_dir <- file.path(out_dir, "feasibility_parts")
dir.create(parts_dir, recursive = TRUE, showWarnings = FALSE)

library(parallel)
library(ggplot2)

profiles <- c("a4", "a5")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
source("R/benchmark_targets.R")

lvl <- 65

# Natively how open_nl() computes the input speech spectrum


input_speech <- build_opennl_speech(hl_freqs, lvl)

cap_seq <- seq(4.0, 14.0, by = 0.5)
floor_seq <- c(0, -5.0, -10.0, -15.0)

if (is_smoke) {
  profiles <- profiles[1:2]
  cap_seq <- cap_seq[1:2]
  floor_seq <- floor_seq[1:2]
}
tasks <- expand.grid(Profile = profiles, Cap = cap_seq, Floor = floor_seq, stringsAsFactors = FALSE)

cat(sprintf("Expected number of optimizations: %d\n", nrow(tasks)))

run_cell <- function(p, c_val, f_val) {
  out_file <- file.path(parts_dir, sprintf("%s_cap%.1f_floor%.1f.csv", p, c_val, f_val))
  if (file.exists(out_file)) {
    return(read.csv(out_file))
  }
  
  start_time <- Sys.time()
  
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  
  res <- tryCatch({
    open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss,
            cap_override = c_val, vent_floor = f_val, optimize = TRUE)
  }, error=function(e) list(error = e$message))
  
  if (is.null(res$error)) {
    hf_gain <- mean(res$gain[4:5])
    
    tgt <- build_target(hl_freqs, input_speech, htl, loss, res$gain)
    sii_complete <- report_sii(tgt, "johnson2011_desensitized")
    sii_smoothed <- report_sii(tgt, "johnson2011_smoothed")
    sii_raw <- report_sii(tgt, "none")
    
    ldn_val <- loudness_of(lvl, res$gain, htl, loss)$total
    is_binding <- (ldn_val >= 0.99 * c_val)
    
    df <- data.frame(
      Profile = p, L_cap = c_val, vent_floor = f_val, HF_Gain = hf_gain,
      SII_complete = sii_complete, SII_smoothed = sii_smoothed, SII_raw = sii_raw,
      Loudness = ldn_val, Binding = is_binding,
      G250 = res$gain[1], G500 = res$gain[2], G1000 = res$gain[3],
      G2000 = res$gain[4], G4000 = res$gain[5], G8000 = res$gain[6], Error = NA
    )
  } else {
    df <- data.frame(
      Profile = p, L_cap = c_val, vent_floor = f_val, HF_Gain = NA,
      SII_complete = NA, SII_smoothed = NA, SII_raw = NA,
      Loudness = NA, Binding = NA,
      G250 = NA, G500 = NA, G1000 = NA, G2000 = NA, G4000 = NA, G8000 = NA
    )
  }
  
  write.csv(df, out_file, row.names = FALSE)
  
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units="secs"))
  cat(sprintf("Cell finished: %s, Cap %.1f, Floor %.1f | Runtime: %.1f s\n", p, c_val, f_val, elapsed))
  
  return(df)
}

cell_results <- mclapply(1:nrow(tasks), function(i) {
  run_cell(tasks$Profile[i], tasks$Cap[i], tasks$Floor[i])
}, mc.cores = 8)

df <- do.call(rbind, cell_results)

# Monotonicity report
cat("\n--- Monotonicity Report ---\n")
for (p in profiles) {
  for (f_val in floor_seq) {
    sub_df <- df[df$Profile == p & df$vent_floor == f_val, ]
    sub_df <- sub_df[order(sub_df$L_cap), ]
    for (i in 2:nrow(sub_df)) {
      if (!is.na(sub_df$SII_smoothed[i]) && !is.na(sub_df$SII_smoothed[i-1])) {
        diff <- sub_df$SII_smoothed[i-1] - sub_df$SII_smoothed[i]
        if (diff > 0.002) {
          cat(sprintf("Cap violation: %s, Floor %.1f | Cap %.1f (SII %.4f) -> Cap %.1f (SII %.4f) [Diff: %.4f]\n", 
                      p, f_val, sub_df$L_cap[i-1], sub_df$SII_smoothed[i-1], sub_df$L_cap[i], sub_df$SII_smoothed[i], diff))
        }
      }
    }
  }
  
  for (c_val in cap_seq) {
    sub_df <- df[df$Profile == p & df$L_cap == c_val, ]
    # Sort descending so tighter floors (e.g. 0) come before looser floors (e.g. -15)
    sub_df <- sub_df[order(sub_df$vent_floor, decreasing = TRUE), ]
    for (i in 2:nrow(sub_df)) {
      if (!is.na(sub_df$SII_smoothed[i]) && !is.na(sub_df$SII_smoothed[i-1])) {
        diff <- sub_df$SII_smoothed[i-1] - sub_df$SII_smoothed[i]
        if (diff > 0.002) {
          cat(sprintf("Floor violation: %s, Cap %.1f | Floor %.1f (SII %.4f) -> Floor %.1f (SII %.4f) [Diff: %.4f]\n", 
                      p, c_val, sub_df$vent_floor[i-1], sub_df$SII_smoothed[i-1], sub_df$vent_floor[i], sub_df$SII_smoothed[i], diff))
        }
      }
    }
  }
}

write.csv(df, file.path(out_dir, "feasibility_grid.csv"), row.names=FALSE)

for (p in profiles) {
  p_df <- df[df$Profile == p, ]
  norm_cap <- lcap(lvl)
  
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6 <- approx(log10(target_data$freq), nal_gain_19, log10(hl_freqs), rule=2)$y
  nal_loudness <- loudness_of(lvl, nal_gain_6, htl, loss)$total

  g1 <- ggplot(p_df, aes(x = L_cap, y = vent_floor, z = HF_Gain)) +
    geom_contour_filled() +
    geom_point(aes(x = nal_loudness, y = 0), color="red", size=4, shape=4) +
    geom_vline(xintercept = norm_cap, linetype="dashed", color="blue") +
    annotate("text", x = nal_loudness, y = 0.5, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("HF Gain Map -", toupper(p)), x = "Loudness Cap (sones)", y = "LF Floor (dB)", fill = "2-4 kHz gain of SII-optimal solution") +
    theme_minimal()
  ggsave(file.path(out_dir, sprintf("feasibility_hf_%s.png", p)), plot=g1, width=7, height=5, bg="white")
  
  g2 <- ggplot(p_df, aes(x = L_cap, y = vent_floor, z = SII_complete)) +
    geom_contour_filled() +
    geom_point(aes(x = nal_loudness, y = 0), color="red", size=4, shape=4) +
    geom_vline(xintercept = norm_cap, linetype="dashed", color="blue") +
    annotate("text", x = nal_loudness, y = 0.5, label="NAL-NL2", color="red", fontface="bold") +
    labs(title = paste("SII Map -", toupper(p)), x = "Loudness Cap (sones)", y = "LF Floor (dB)", fill = "SII") +
    theme_minimal()
  ggsave(file.path(out_dir, sprintf("feasibility_sii_%s.png", p)), plot=g2, width=7, height=5, bg="white")
}
