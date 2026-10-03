## audit_nal_ldf.R -----------------------------------------------------------
## How much does the nal_ldf flag change the reported SII?
##
## R/sii.R lines 506-515: with nal_ldf = TRUE the speech level distortion
## factor becomes
##     Li = 1 - (E'i - Ui - 10 - Ji - 0.5*T'i) / 160
## instead of the ANSI S3.5 form
##     Li = 1 - (E'i - Ui - 10 - Ji) / 160
## so the penalty onset shifts up by half the hearing threshold. Li is clamped
## to [0,1] and multiplies band audibility.
##
## report_sii() defaults nal_ldf = TRUE and compute_sii() inside open_nl()
## passes TRUE, so the optimizer and three of the four reported SII variants
## use the modified form. Only the "ansi" column uses the standard one.
##
## Keidser et al. (2011) describes NAL-NL2's SII change as an effective
## AUDIBILITY factor (the Ching et al. desensitization term), and says nothing
## about the level distortion factor. The 0.5 coefficient has no located
## source. This script measures whether it matters.
##
## Two parts:
##   A  canonical profiles A1-A7, unaided and NAL-NL2-aided
##   B  every cell of the stored audiogram family run, rescored both ways
##
## No optimizer: it rescores stored gain vectors. Safe beside a long job.
## Run from the repository root.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

log_path <- file.path("reproducibility_scripts", "output",
                      sprintf("audit_nal_ldf_%s.log", Sys.Date()))
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("audit_nal_ldf.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
sp65 <- build_opennl_speech(hl_freqs, 65)

score <- function(htl, gain, ldf, desens = "johnson2011_smoothed", scale = 1) {
  tgt <- build_target(hl_freqs, sp65, htl, rep(0, 6), gain, eval_level = 65)
  report_sii(tgt, desens, nal_ldf = ldf, desensitization_scale = scale)
}

## ---- Part A: canonical profiles -----------------------------------------

cat("==== PART A: A1-A7, smoothed desensitization, scale 1 ====\n\n")
cat("  profile  condition        SII (ldf on)  SII (ldf off)     difference\n")

for (p in names(jd2011_targets)) {
  htl <- jd2011_targets[[p]]$threshold

  on0  <- score(htl, rep(0, 6), TRUE)
  off0 <- score(htl, rep(0, 6), FALSE)
  cat(sprintf("  %-7s  unaided        %13.4f %14.4f %14.4f\n",
              p, on0, off0, on0 - off0))

  g <- tryCatch(as.numeric(get_nalnl2_v2_target(p, "NAL-NL2", hl_freqs, 65))[1:6],
                error = function(e) NULL)
  if (is.null(g) || any(is.na(g))) {
    cat(sprintf("  %-7s  NAL-NL2 aided  %13s\n", p, "unavailable"))
  } else {
    on1  <- score(htl, g, TRUE)
    off1 <- score(htl, g, FALSE)
    cat(sprintf("  %-7s  NAL-NL2 aided  %13.4f %14.4f %14.4f\n",
                p, on1, off1, on1 - off1))
  }
}

cat("\n-- the same, with high gain: +30 dB at 2-8 kHz --\n")
cat("   (the regime the floor analysis pushes into, where Li should bite)\n\n")
cat("  profile     SII (ldf on)  SII (ldf off)     difference\n")
for (p in c("a1", "a3", "a4", "a5")) {
  htl <- jd2011_targets[[p]]$threshold
  g <- c(0, 0, 0, 30, 30, 30)
  on1 <- score(htl, g, TRUE); off1 <- score(htl, g, FALSE)
  cat(sprintf("  %-7s %13.4f %14.4f %14.4f\n", p, on1, off1, on1 - off1))
}

## ---- Part B: rescore the stored family run both ways --------------------

cat("\n\n==== PART B: stored audiogram family cells, rescored ====\n\n")

fp <- "reproducibility_scripts/output/jaaa_audmod/family_parts"
if (!dir.exists(fp)) {
  cat("  family_parts/ not found - skipping Part B\n")
} else {
  raw <- do.call(rbind, lapply(list.files(fp, full.names = TRUE), read.csv))
  gcols <- c("G250", "G500", "G1000", "G2000", "G4000", "G8000")

  raw$sii_ldf_off <- NA_real_
  for (i in seq_len(nrow(raw))) {
    htl <- c(10, 10, 10,
             approx(c(1000, 1500, 2000, 3000), c(NA, NA, NA, NA), 1)$y)  # placeholder
    ## thresholds are not stored per cell; rebuild from Edge/Slope
    e <- raw$Edge[i]; s <- raw$Slope[i]
    f_oct <- log2(hl_freqs / e)
    htl <- pmin(110, pmax(10, 10 + s * pmax(0, f_oct)))
    g <- as.numeric(raw[i, gcols])
    raw$sii_ldf_off[i] <- score(htl, g, FALSE, "johnson2011_smoothed", raw$Scale[i])
  }

  raw$d_ldf <- raw$sii_smoothed_s - raw$sii_ldf_off
  cat("  difference (ldf on minus ldf off) across all cells:\n")
  print(summary(raw$d_ldf))
  cat("\n  by audible edge frequency:\n")
  print(round(tapply(raw$d_ldf, raw$Edge, mean), 4))
  cat("\n  by slope:\n")
  print(round(tapply(raw$d_ldf, raw$Slope, mean), 4))

  cat("\n  NOTE: thresholds are reconstructed from Edge and Slope, so Part B is\n")
  cat("  approximate where that reconstruction differs from the family script.\n")
  cat("  Check a row against gen_audiogram_family.R before relying on it.\n")
}

cat("\n\nfinished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("log written to:", log_path, "\n")
sink()
