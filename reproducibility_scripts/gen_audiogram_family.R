#!/usr/bin/env Rscript
set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

is_smoke <- Sys.getenv("JAAA_SMOKE") == "1"
out_dir <- if (is_smoke) "reproducibility_scripts/output/jaaa_audmod_smoke/" else "reproducibility_scripts/output/jaaa_audmod/"
write_run_metadata(out_dir)
parts_dir <- file.path(out_dir, "family_parts")
unlink(file.path(parts_dir, "*.csv"))
dir.create(parts_dir, recursive = TRUE, showWarnings = FALSE)

library(parallel)
library(ggplot2)

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
edges <- c(1000, 1500, 2000, 3000)
slopes <- c(20, 30, 40, 50)
lvl <- 65

# ---------------------------------------------------------
# Build Audiogram Family
# ---------------------------------------------------------
profiles <- list()
for (e in edges) {
  for (s in slopes) {
    name <- sprintf("e%d_s%d", e, s)
    htl <- sapply(hl_freqs, function(f) {
      if (f <= e) {
        return(10)
      } else {
        return(min(110, 10 + s * log2(f / e)))
      }
    })
    profiles[[name]] <- list(Edge = e, Slope = s, htl = htl)
  }
}

# Print full 16x6 threshold table
thresh_mat <- do.call(rbind, lapply(profiles, function(x) x$htl))
rownames(thresh_mat) <- names(profiles)
colnames(thresh_mat) <- paste0(hl_freqs, "Hz")
cat("Audiogram Family Thresholds:\n")
print(thresh_mat)

# ---------------------------------------------------------
# Compare to A4 / A5
# ---------------------------------------------------------
jd_a4 <- jd2011_targets$a4$threshold
jd_a5 <- jd2011_targets$a5$threshold

rms_diff <- function(x, y) sqrt(mean((x - y)^2))
a4_rms <- sapply(profiles, function(p) rms_diff(p$htl, jd_a4))
a5_rms <- sapply(profiles, function(p) rms_diff(p$htl, jd_a5))

cat(sprintf("\nClosest to A4: %s (RMS diff = %.2f dB)\n", names(which.min(a4_rms)), min(a4_rms)))
cat(sprintf("Closest to A5: %s (RMS diff = %.2f dB)\n\n", names(which.min(a5_rms)), min(a5_rms)))


# ---------------------------------------------------------
# Define Job Grid
# ---------------------------------------------------------
profile_names <- names(profiles)
desens_scales <- c(0, 0.5, 1)
floors <- c(0, -10)
budgets <- c(0.5, 1, 2, 3)

if (is_smoke) {
  profile_names <- profile_names[1:2]
  desens_scales <- c(0, 1)
  budgets <- c(0.5, 3)
}

tasks <- expand.grid(Profile = profile_names, Budget = budgets, Scale = desens_scales, Floor = floors, stringsAsFactors = FALSE)


# ---------------------------------------------------------
# Worker Function
# ---------------------------------------------------------
# Passing the audiogram list explicitly to avoid relying on environment inheritance
run_cell <- function(job_idx, prof_list) {
  p <- tasks$Profile[job_idx]
  b <- tasks$Budget[job_idx]
  s <- tasks$Scale[job_idx]
  f_val <- tasks$Floor[job_idx]
  
  out_file <- file.path(parts_dir, sprintf("%s_budget%.1f_scale%s_floor%d.csv", p, b, s, f_val))
  if (file.exists(out_file)) return(read.csv(out_file))
  
  prof_data <- prof_list[[p]]
  htl <- prof_data$htl
  edge_val <- prof_data$Edge
  slope_val <- prof_data$Slope
  loss <- rep(0, 6)
  
  input_speech <- build_opennl_speech(hl_freqs, lvl)
  
  # Capped at unaided loudness + budget sones
  L0 <- loudness_of(lvl, rep(0, 6), htl, loss)$total
  cap_val <- L0 + b
  
  res <- tryCatch({
    open_nl(speech = lvl, threshold = htl, freq = hl_freqs, loss = loss, 
            cap_override = cap_val, vent_floor = f_val, desensitization_scale = s, optimize = TRUE)
  }, error = function(e) list(error = e$message))
  
  if (is.null(res$error)) {
    tgt <- build_target(hl_freqs, input_speech, htl, loss, res$gain, eval_level = lvl)
    sii_smoothed_s <- report_sii(tgt, "johnson2011_smoothed", desensitization_scale = s)
    sii_complete_s <- report_sii(tgt, "johnson2011_complete", desensitization_scale = s)
    sii_complete_full <- report_sii(tgt, "johnson2011_complete", desensitization_scale = 1.0)
    sii_ansi <- report_sii(tgt, "none", nal_ldf = FALSE, desensitization_scale = 1.0)
    ldn_val <- loudness_of(lvl, res$gain, htl, loss)$total
    
    df <- data.frame(
      Profile = p, Edge = edge_val, Slope = slope_val, Budget = b, Scale = s, vent_floor = f_val,
      sii_smoothed_s = sii_smoothed_s, sii_complete_s = sii_complete_s,
      sii_complete_full = sii_complete_full, sii_ansi = sii_ansi,
      Loudness = ldn_val, L0 = L0, cap_val = cap_val,
      G250 = res$gain[1], G500 = res$gain[2], G1000 = res$gain[3],
      G2000 = res$gain[4], G4000 = res$gain[5], G8000 = res$gain[6], Error = NA
    )
  } else {
    df <- data.frame(
      Profile = p, Edge = edge_val, Slope = slope_val, Budget = b, Scale = s, vent_floor = f_val,
      sii_smoothed_s = NA, sii_complete_s = NA,
      sii_complete_full = NA, sii_ansi = NA,
      Loudness = NA, L0 = L0, cap_val = cap_val,
      G250 = NA, G500 = NA, G1000 = NA,
      G2000 = NA, G4000 = NA, G8000 = NA, Error = res$error
    )
  }
  
  write.csv(df, out_file, row.names = FALSE)
  return(df)
}

# ---------------------------------------------------------
# Execution & Aggregation
# ---------------------------------------------------------
cell_results <- mclapply(1:nrow(tasks), function(i) {
  run_cell(i, profiles)
}, mc.cores = 8)

df <- do.call(rbind, cell_results)

# Calculate Floor effects
floor_effects <- data.frame()
for (p in profile_names) {
  for (b_val in budgets) {
    for (s_val in desens_scales) {
      df_0 <- df[df$Profile == p & df$Budget == b_val & df$Scale == s_val & df$vent_floor == 0, ]
      df_10 <- df[df$Profile == p & df$Budget == b_val & df$Scale == s_val & df$vent_floor == -10, ]
      
      if (nrow(df_0) > 0 && nrow(df_10) > 0 && is.na(df_0$Error[1]) && is.na(df_10$Error[1])) {
        floor_effects <- rbind(floor_effects, data.frame(
          Profile = p, Edge = df_0$Edge, Slope = df_0$Slope, Budget = b_val, Scale = s_val,
          L0 = df_0$L0, cap_val = df_0$cap_val,
          diff_smoothed_s = df_10$sii_smoothed_s - df_0$sii_smoothed_s,
          diff_complete_s = df_10$sii_complete_s - df_0$sii_complete_s,
          diff_complete_full = df_10$sii_complete_full - df_0$sii_complete_full,
          diff_ansi = df_10$sii_ansi - df_0$sii_ansi
        ))
      }
    }
  }
}

write.csv(df, file.path(out_dir, "audiogram_family_raw.csv"), row.names = FALSE)
write.csv(floor_effects, file.path(out_dir, "audiogram_family_diffs.csv"), row.names = FALSE)

# ---------------------------------------------------------
# Figure Generation
# ---------------------------------------------------------
floor_effects$Edge_f <- as.factor(floor_effects$Edge)
floor_effects$Slope_f <- as.factor(floor_effects$Slope)

scale_labeller <- function(x) paste("Desensitization scale =", x)
budget_labeller <- function(x) paste("Budget =", x, "sones")

# Full heatmap (Supplementary)
g1_supp <- ggplot(floor_effects, aes(x = Edge_f, y = Slope_f, fill = diff_smoothed_s)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.3f", diff_smoothed_s)), size = 3, color = "white") +
  facet_grid(Budget ~ Scale, labeller = labeller(Scale = as_labeller(scale_labeller), Budget = as_labeller(budget_labeller))) +
  scale_fill_viridis_c(name = "SII change: -10 dB minus 0 dB minimum gain") +
  labs(x = "Edge frequency (Hz)", y = "Slope (dB/octave)") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "audiogram_family_supp.png"), plot = g1_supp, width = 12, height = 10, bg = "white", dpi = 300)
ggsave(file.path(out_dir, "audiogram_family_supp.pdf"), plot = g1_supp, width = 12, height = 10, bg = "white")

# Main heatmap (Budgets 0.5 and 1)
floor_effects_sub <- floor_effects[floor_effects$Budget %in% c(0.5, 1), ]
g1_main <- ggplot(floor_effects_sub, aes(x = Edge_f, y = Slope_f, fill = diff_smoothed_s)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.3f", diff_smoothed_s)), size = 3, color = "white") +
  facet_grid(Budget ~ Scale, labeller = labeller(Scale = as_labeller(scale_labeller), Budget = as_labeller(budget_labeller))) +
  scale_fill_viridis_c(name = "SII change: -10 dB minus 0 dB minimum gain") +
  labs(x = "Edge frequency (Hz)", y = "Slope (dB/octave)") +
  theme_minimal() +
  theme(legend.position = "bottom")

ggsave(file.path(out_dir, "audiogram_family_main.png"), plot = g1_main, width = 12, height = 6, bg = "white", dpi = 300)
ggsave(file.path(out_dir, "audiogram_family_main.pdf"), plot = g1_main, width = 12, height = 6, bg = "white")

g2 <- ggplot(floor_effects, aes(x = Budget, y = diff_smoothed_s, group = Profile, color = Edge_f, linetype = Slope_f)) +
  geom_hline(yintercept = 0.02, linetype = "dotted", colour = "grey50") +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  facet_wrap(~ Scale, labeller = as_labeller(scale_labeller)) +
  scale_linetype_manual(values = c("20" = "solid", "30" = "22", "40" = "42", "50" = "1343")) +
  scale_x_continuous(breaks = c(0.5, 1, 2, 3)) +
  labs(x = "Loudness budget above unaided (sones)", 
       y = "SII change: -10 dB minus 0 dB minimum gain", 
       color = "Edge (Hz)", 
       linetype = "Slope (dB/oct)") +
  theme_minimal() +
  theme(legend.position = "right")

ggsave(file.path(out_dir, "audiogram_family_budget.png"), plot = g2, width = 12, height = 5, bg = "white", dpi = 300)
ggsave(file.path(out_dir, "audiogram_family_budget.pdf"), plot = g2, width = 12, height = 5, bg = "white")

cat("Audiogram family sensitivity analysis complete.
")
