## masking_check.R -------------------------------------------------------------
## Tests the manuscript's claim that, in the anchor-off sweep, part of the floor
## effect comes from reduced upward spread of masking inside the SII rather
## than from freed loudness budget.
##
## No optimizer. Scores stored anchor-off gains from anchor_off_starts20.csv.
## Runs in seconds.
##
## Two tests per case:
##  1. Counterfactual: keep the 0 dB-floor solution's 2/4/8 kHz gains and apply
##     only the -10 dB solution's 250/500/1000 Hz gains ("LF cut only"). The low
##     bands themselves lose audibility, so any SII gain from this must come from
##     the bands above them, i.e. from masking release.
##  2. Band worksheet: for each band, whether its disturbance Di is set by the
##     masking term Zi (masking-limited) or by threshold X'i, and how much of the
##     SII change comes from masking-limited bands.
##
## Level distortion (Li) cannot be the mechanism: with 0 dB low-frequency gain
## at 65 dB SPL, E'i - Ui is about +2.6 dB, below the 10 dB onset, so Li = 1
## already and cutting low-frequency gain cannot raise it.
##
## Run from the repo root:
##   source("reproducibility_scripts/masking_check.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")

hl <- c(250, 500, 1000, 2000, 4000, 8000)
sp <- build_opennl_speech(hl, 65)
gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")

## Three unspent-budget pairs from the sweep, plus A4 from the iso-loudness
## control as a precipitous comparison. Audiograms as in the rebuild script.
CASES <- list(
  e1500_s20 = c(10, 10, 10, 18.30075, 38.30075, 58.30075),
  e2000_s20 = c(10, 10, 10, 10.00000, 30.00000, 50.00000),
  e2000_s30 = c(10, 10, 10, 10.00000, 40.00000, 70.00000),
  a4        = c( 0,  0, 10, 40,       70,       80))

a <- read.csv("reproducibility_scripts/output/isoloudness/anchor_off_starts20.csv",
              stringsAsFactors = FALSE)
gain_of <- function(p, f) as.numeric(a[a$profile == p & a$floor == f, gcols])

score <- function(th, gv, des) {
  tg <- build_target(hl, sp, th, rep(0, 6), gv, 65)
  SII::sii(speech = tg$orig_speech, noise = rep(-50, 6), threshold = th,
           loss = rep(0, 6), freq = hl, prescription = tg, interpolate = TRUE,
           nal_ldf = FALSE, desensitization = des)
}

for (nm in names(CASES)) {
  th  <- CASES[[nm]]
  g0  <- gain_of(nm, 0); g10 <- gain_of(nm, -10)
  lf_only <- c(g10[1:3], g0[4:6])
  hf_only <- c(g0[1:3], g10[4:6])

  cat(sprintf("\n==== %s ====\n", nm))
  cat("                    smoothed    ANSI\n")
  for (lab in c("floor 0", "floor -10", "LF cut only", "HF change only")) {
    gv <- switch(lab, "floor 0" = g0, "floor -10" = g10,
                 "LF cut only" = lf_only, "HF change only" = hf_only)
    cat(sprintf("  %-16s  %.4f     %.4f\n", lab,
                score(th, gv, "johnson2011_smoothed")$sii, score(th, gv, "none")$sii))
  }

  r0  <- as.data.frame(score(th, g0,  "johnson2011_smoothed")$table, check.names = FALSE)
  r10 <- as.data.frame(score(th, g10, "johnson2011_smoothed")$table, check.names = FALSE)
  mask0 <- r0[["Zi"]] > r0[["X'i"]]            # masking-limited at floor 0
  d_iiai <- r10[["IiAi"]] - r0[["IiAi"]]
  band <- data.frame(Fi = r0$Fi,
                     Zi_0 = round(r0$Zi, 1), Zi_10 = round(r10$Zi, 1),
                     Xp = round(r0[["X'i"]], 1),
                     mask_limited = mask0,
                     dIiAi = round(d_iiai, 4))
  print(band[band$Fi >= 800 & band$Fi <= 6000, ], row.names = FALSE)
  cat(sprintf("  SII change from masking-limited bands: %+.4f of %+.4f total\n",
              sum(d_iiai[mask0]), sum(d_iiai)))
}
