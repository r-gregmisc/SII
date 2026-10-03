#!/usr/bin/env Rscript
## gen_iso_loudness_control_v2.R ----------------------------------------------
## Iso-loudness control experiment, rerun at 20 multi-starts with the
## vent_floor dual-run branch disabled.
##
## What changed from gen_iso_loudness_control.R:
##
##   1. open_nl() runs the optimization twice when vent_floor < 0 and returns
##      the better branch on raw SII (R/open_nl.R lines 381-395, 404-418). The
##      floor effect reported in Table 2 was therefore max(0, delta). This
##      script disables that branch in an in-memory copy, so each floor is
##      optimized once, at the floor requested.
##
##   2. Three multi-starts under-converged the floor-0 side; 20 are used here.
##
##   3. nal_ldf is now FALSE throughout (fixed in the package), so the SII uses
##      the standard ANSI S3.5 level distortion factor.
##
## The design is otherwise unchanged: the cap is NAL-NL2's own achieved
## loudness for that profile, so the comparison is exactly iso-loudness.
##
## Runtime: 14 optimizations at 20 starts, roughly 45-60 minutes.
## Writes table2_iso_loudness_v2.csv, leaving the original file in place.
## -----------------------------------------------------------------------------

set.seed(20260916)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

STARTS <- 20

is_smoke <- Sys.getenv("JAAA_SMOKE") == "1"
out_dir  <- if (is_smoke) "reproducibility_scripts/output/jaaa_audmod_smoke/" else
                          "reproducibility_scripts/output/jaaa_audmod/"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
write_run_metadata(out_dir)
out_file <- file.path(out_dir, "table2_iso_loudness_v2.csv")
log_file <- file.path(out_dir, sprintf("table2_iso_loudness_v2_%s.log", Sys.Date()))
con <- file(log_file, open = "wt"); sink(con, split = TRUE)

cat("gen_iso_loudness_control_v2.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("starts %d | open_nl_maxit %s\n", STARTS,
            getOption("open_nl_maxit", "unset")))

## Record the level-distortion setting in force rather than assuming it.
ldf_sites <- grep("nal_ldf", readLines("R/open_nl.R"), value = TRUE)
cat("nal_ldf in R/open_nl.R:\n")
for (l in ldf_sites) cat("   ", trimws(l), "\n")
if (any(grepl("nal_ldf\\s*=\\s*TRUE", ldf_sites))) {
  cat("\nABORT: open_nl.R still passes nal_ldf = TRUE somewhere.\n")
  sink(); stop("Fix R/open_nl.R before running.")
}

## ---- in-memory copy of open_nl() with the dual run disabled ---------------

ns  <- asNamespace("SII")
## The vent_floor dual-run branch has been removed from R/open_nl.R, so each
## floor is optimized once at the floor requested without patching.
src <- readLines("R/open_nl.R")

tmp <- tempfile(fileext = ".R"); writeLines(src, tmp)
e <- new.env(parent = ns); sys.source(tmp, envir = e)
open_nl_single <- e$open_nl; environment(open_nl_single) <- ns
cat("each floor optimized once at the floor requested\n\n")

options(open_nl_starts = STARTS)

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
profiles <- paste0("a", 1:7)
if (is_smoke) profiles <- profiles[1:2]

lvl <- 65
input_speech <- build_opennl_speech(hl_freqs, lvl)

results <- data.frame()
t_start <- Sys.time(); n_done <- 0
n_total <- length(profiles) * 2
cat(sprintf("%d optimizations to do\n\n", n_total))

for (p in profiles) {
  target_data <- jd2011_targets[[p]]
  htl  <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", target_data$freq, lvl)
  nal_gain_6  <- approx(log10(target_data$freq), nal_gain_19,
                        log10(hl_freqs), rule = 2)$y
  nal_loudness <- loudness_of(lvl, nal_gain_6, htl, loss)$total

  tgt_nal <- build_target(hl_freqs, input_speech, htl, loss, nal_gain_6,
                          eval_level = lvl)
  sii_nal_desens <- report_sii(tgt_nal, "johnson2011_complete")
  sii_nal_raw    <- report_sii(tgt_nal, "none", nal_ldf = FALSE)
  sii_nal_smooth <- report_sii(tgt_nal, "johnson2011_smoothed")

  cat(sprintf("%-3s  NAL-NL2 cap %7.4f sones | SII smoothed %.4f\n",
              p, nal_loudness, sii_nal_smooth))

  ## --- floor 0 -------------------------------------------------------------
  res_0 <- open_nl_single(speech = lvl, threshold = htl, freq = hl_freqs,
                          loss = loss, cap_override = nal_loudness,
                          vent_floor = 0)
  tgt_0 <- build_target(hl_freqs, input_speech, htl, loss, res_0$gain,
                        eval_level = lvl)
  sii_onl_0_desens <- report_sii(tgt_0, "johnson2011_complete")
  sii_onl_0_raw    <- report_sii(tgt_0, "none", nal_ldf = FALSE)
  sii_onl_0_smooth <- report_sii(tgt_0, "johnson2011_smoothed")
  onl_0_loudness   <- loudness_of(lvl, res_0$gain, htl, loss)$total

  n_done <- n_done + 1
  el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  cat(sprintf("     floor   0: %7.4f sones (cap %+.4f) | SII smoothed %.4f   [%2d/%2d, %.0fm elapsed, ~%.0fm left]\n",
              onl_0_loudness, onl_0_loudness - nal_loudness, sii_onl_0_smooth,
              n_done, n_total, el, (n_total - n_done) * el / n_done))

  ## --- floor -10 -----------------------------------------------------------
  res_10 <- open_nl_single(speech = lvl, threshold = htl, freq = hl_freqs,
                           loss = loss, cap_override = nal_loudness,
                           vent_floor = -10)
  tgt_10 <- build_target(hl_freqs, input_speech, htl, loss, res_10$gain,
                         eval_level = lvl)
  sii_onl_10_desens <- report_sii(tgt_10, "johnson2011_complete")
  sii_onl_10_raw    <- report_sii(tgt_10, "none", nal_ldf = FALSE)
  sii_onl_10_smooth <- report_sii(tgt_10, "johnson2011_smoothed")
  onl_10_loudness   <- loudness_of(lvl, res_10$gain, htl, loss)$total

  n_done <- n_done + 1
  el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  cat(sprintf("     floor -10: %7.4f sones (cap %+.4f) | SII smoothed %.4f   [%2d/%2d, %.0fm elapsed, ~%.0fm left]\n",
              onl_10_loudness, onl_10_loudness - nal_loudness, sii_onl_10_smooth,
              n_done, n_total, el, (n_total - n_done) * el / n_done))

  neg_bands <- paste(hl_freqs[res_10$gain < -0.001], collapse = "/")
  cat(sprintf("     floor effect (smoothed) %+.4f | optimizer effect %+.4f | iso? %s | neg bands %s\n\n",
              sii_onl_10_smooth - sii_onl_0_smooth,
              sii_onl_0_smooth  - sii_nal_smooth,
              if (abs(onl_10_loudness - onl_0_loudness) <= 0.001) "yes" else "NO",
              if (nzchar(neg_bands)) neg_bands else "none"))

  max_diff_smooth <- max(abs(sii_onl_0_desens - sii_onl_0_smooth),
                         abs(sii_onl_10_desens - sii_onl_10_smooth))

  results <- rbind(results, data.frame(
    Profile = p, Starts = STARTS, NalLdf = FALSE,
    NAL_Loudness = nal_loudness,
    NAL_SII_Desens = sii_nal_desens,
    NAL_SII_Raw = sii_nal_raw,
    NAL_SII_Smooth = sii_nal_smooth,
    ONL0_SII_Desens = sii_onl_0_desens,
    ONL0_SII_Smooth = sii_onl_0_smooth,
    ONL0_SII_Raw = sii_onl_0_raw,
    ONL0_Loudness = onl_0_loudness,
    ONL10_SII_Desens = sii_onl_10_desens,
    ONL10_SII_Smooth = sii_onl_10_smooth,
    ONL10_SII_Raw = sii_onl_10_raw,
    ONL10_Loudness = onl_10_loudness,
    Opt_Effect_Desens = sii_onl_0_desens - sii_nal_desens,
    Opt_Effect_Raw = sii_onl_0_raw - sii_nal_raw,
    Opt_Effect_Smooth = sii_onl_0_smooth - sii_nal_smooth,
    Floor_Effect_Desens = sii_onl_10_desens - sii_onl_0_desens,
    Floor_Effect_Raw = sii_onl_10_raw - sii_onl_0_raw,
    Floor_Effect_Smooth = sii_onl_10_smooth - sii_onl_0_smooth,
    Iso_Loudness_Diff = onl_10_loudness - onl_0_loudness,
    N_Neg_Bands = sum(res_10$gain < -0.001),
    Neg_Bands = neg_bands,
    Max_Diff_Smooth = max_diff_smooth,
    NAL_G250 = nal_gain_6[1], NAL_G500 = nal_gain_6[2], NAL_G1000 = nal_gain_6[3],
    NAL_G2000 = nal_gain_6[4], NAL_G4000 = nal_gain_6[5], NAL_G8000 = nal_gain_6[6],
    ONL0_G250 = res_0$gain[1], ONL0_G500 = res_0$gain[2], ONL0_G1000 = res_0$gain[3],
    ONL0_G2000 = res_0$gain[4], ONL0_G4000 = res_0$gain[5], ONL0_G8000 = res_0$gain[6],
    ONL10_G250 = res_10$gain[1], ONL10_G500 = res_10$gain[2], ONL10_G1000 = res_10$gain[3],
    ONL10_G2000 = res_10$gain[4], ONL10_G4000 = res_10$gain[5], ONL10_G8000 = res_10$gain[6],
    stringsAsFactors = FALSE))

  write.csv(results, out_file, row.names = FALSE)   # checkpoint per profile
}

cat("\n\n==== Summary: iso-loudness control, 20 starts, single-branch ====\n\n")
cat("  profile   cap    ONL0    ONL-10   iso?   optimizer   floor    neg bands\n")
for (i in seq_len(nrow(results))) {
  r <- results[i, ]
  cat(sprintf("  %-7s %6.3f  %6.3f  %6.3f   %-4s  %+8.4f  %+8.4f   %s\n",
              r$Profile, r$NAL_Loudness, r$ONL0_Loudness, r$ONL10_Loudness,
              if (abs(r$Iso_Loudness_Diff) <= 0.001) "yes" else "NO",
              r$Opt_Effect_Smooth, r$Floor_Effect_Smooth,
              if (nzchar(r$Neg_Bands)) r$Neg_Bands else "none"))
}

cat("\n  Floor effect by desensitization treatment:\n")
print(data.frame(Profile = results$Profile,
                 smoothed = round(results$Floor_Effect_Smooth, 4),
                 complete = round(results$Floor_Effect_Desens, 4),
                 raw_ansi = round(results$Floor_Effect_Raw, 4)),
      row.names = FALSE)

cat(sprintf("\nWrote %s\n", out_file))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
options(open_nl_starts = 3); rm(open_nl_single)
sink()
