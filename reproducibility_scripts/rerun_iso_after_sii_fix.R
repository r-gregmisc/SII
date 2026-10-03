## rerun_iso_after_sii_fix.R ---------------------------------------------------
## Reruns the iso-loudness control (Tables 4 and 5, anchor on) and the anchor-off
## iso-loudness profiles A1-A5 (Table 5, anchor off) after the fix to R/sii.R
## that stops negative insertion gain from being floored at 0 dB in the SII.
##
## Why only these: rescore_negative_gain_unclipped.R showed that every stored
## sweep solution (Table 3, anchor on and off) and A1, A3, A4, A5 score
## identically with or without the clip. Only A2, whose -10 dB solution cuts gain
## at 4000 Hz, changed. The iso-loudness control is rerun in full, not just A2,
## so Tables 4 and 5 all come from one version of the code.
##
## Steps
##   1. Checks that R/sii.R carries the fix.
##   2. Backs up table2_iso_loudness_v2.csv and anchor_off_starts20.csv as
##      *_pre_siifix.csv (first run only), and removes the part-B rows from
##      anchor_off_starts20.csv so anchor_off_check.R reruns only A1-A5.
##   3. Runs gen_iso_loudness_control_v2.R   (14 optimizations, ~45-60 min)
##   4. Runs anchor_off_check.R, part B only (10 optimizations, ~35 min)
##   5. Prints old vs new floor effects for Tables 4 and 5.
##
## Safe to re-source if interrupted: backups are made once, and
## anchor_off_check.R resumes from its CSV. (gen_iso_loudness_control_v2.R
## restarts from the beginning.) If a script stops with an error, run  sink()
## once at the prompt before sourcing this again.
##
## Run from the repo root:
##   source("reproducibility_scripts/rerun_iso_after_sii_fix.R")
## -----------------------------------------------------------------------------

## ---- 1. the fix must be in place --------------------------------------------
s <- readLines("R/sii.R")
if (any(grepl("gain <- pmax(final_output - speech, 0)", s, fixed = TRUE)) ||
    !any(grepl("^\\s*gain <- final_output - speech\\s*$", s)))
  stop("R/sii.R does not carry the negative-gain fix; aborting.")
cat("R/sii.R: negative insertion gain passed through (fix present)\n")

## ---- 2. backups and part-B reset --------------------------------------------
iso_csv <- "reproducibility_scripts/output/jaaa_audmod/table2_iso_loudness_v2.csv"
ao_csv  <- "reproducibility_scripts/output/isoloudness/anchor_off_starts20.csv"
iso_bak <- sub("\\.csv$", "_pre_siifix.csv", iso_csv)
ao_bak  <- sub("\\.csv$", "_pre_siifix.csv", ao_csv)

if (!file.exists(iso_bak)) { file.copy(iso_csv, iso_bak); cat("backed up", iso_csv, "\n") }
if (!file.exists(ao_bak)) {
  file.copy(ao_csv, ao_bak); cat("backed up", ao_csv, "\n")
  ao <- read.csv(ao_csv, stringsAsFactors = FALSE)
  write.csv(ao[ao$part != "B", ], ao_csv, row.names = FALSE)
  cat("removed part-B rows from", ao_csv, "so A1-A5 are re-optimized\n")
}

## ---- 3. iso-loudness control, anchor on --------------------------------------
cat("\n==== gen_iso_loudness_control_v2.R ====\n")
source("reproducibility_scripts/gen_iso_loudness_control_v2.R")

## ---- 4. anchor off, part B ---------------------------------------------------
cat("\n==== anchor_off_check.R (part A already done; reruns part B) ====\n")
source("reproducibility_scripts/anchor_off_check.R")

## ---- 5. old vs new -------------------------------------------------------------
old_on  <- read.csv(iso_bak, stringsAsFactors = FALSE)
new_on  <- read.csv(iso_csv, stringsAsFactors = FALSE)
old_off <- read.csv(ao_bak, stringsAsFactors = FALSE); old_off <- old_off[old_off$part == "B", ]
new_off <- read.csv(ao_csv, stringsAsFactors = FALSE); new_off <- new_off[new_off$part == "B", ]

ff_off <- function(d, p, col) d[d$profile == p & d$floor == -10, col] - d[d$profile == p & d$floor == 0, col]

cat("\n\n==== Table 4: smoothed SII, anchor on (old -> new) ====\n")
for (p in new_on$Profile) {
  o <- old_on[old_on$Profile == p, ]; n <- new_on[new_on$Profile == p, ]
  cat(sprintf("  %-3s  NAL %.3f -> %.3f | ONL0 %.3f -> %.3f | ONL-10 %.3f -> %.3f | opt %+.3f -> %+.3f | floor %+.3f -> %+.3f | iso diff %+.4f\n",
              p, o$NAL_SII_Smooth, n$NAL_SII_Smooth, o$ONL0_SII_Smooth, n$ONL0_SII_Smooth,
              o$ONL10_SII_Smooth, n$ONL10_SII_Smooth, o$Opt_Effect_Smooth, n$Opt_Effect_Smooth,
              o$Floor_Effect_Smooth, n$Floor_Effect_Smooth, n$Iso_Loudness_Diff))
}

cat("\n==== Table 5: floor effect (old -> new) ====\n")
cat("  prof   smooth on        smooth off       complete on      complete off     ANSI on          ANSI off\n")
for (p in new_on$Profile) {
  o <- old_on[old_on$Profile == p, ]; n <- new_on[new_on$Profile == p, ]
  off <- if (p %in% new_off$profile) sprintf("%+.3f -> %+.3f", ff_off(old_off, p, "sii_smooth"), ff_off(new_off, p, "sii_smooth")) else "      ---       "
  offc <- if (p %in% new_off$profile) sprintf("%+.3f -> %+.3f", ff_off(old_off, p, "sii_complete"), ff_off(new_off, p, "sii_complete")) else "      ---       "
  offa <- if (p %in% new_off$profile) sprintf("%+.3f -> %+.3f", ff_off(old_off, p, "sii_ansi"), ff_off(new_off, p, "sii_ansi")) else "      ---       "
  cat(sprintf("  %-4s %+.3f -> %+.3f  %s  %+.3f -> %+.3f  %s  %+.3f -> %+.3f  %s\n", p,
              o$Floor_Effect_Smooth, n$Floor_Effect_Smooth, off,
              o$Floor_Effect_Desens, n$Floor_Effect_Desens, offc,
              o$Floor_Effect_Raw, n$Floor_Effect_Raw, offa))
}

cat("\n==== Anchor-off pairs: loudness match (sones, -10 minus 0) ====\n")
for (p in unique(new_off$profile))
  cat(sprintf("  %-3s %+.4f\n", p, ff_off(new_off, p, "sones_model")))

cat("\n==== Optimizer effect (Open-NL 0 dB minus NAL-NL2), new ====\n")
print(data.frame(Profile = new_on$Profile,
                 smoothed = round(new_on$Opt_Effect_Smooth, 3),
                 complete = round(new_on$Opt_Effect_Desens, 3),
                 ansi     = round(new_on$Opt_Effect_Raw, 3)), row.names = FALSE)
cat("\nDone. Paste everything from '==== Table 4' down to Claude.\n")
