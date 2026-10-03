## budget_check.R --------------------------------------------------------------
## Two follow-ups to masking_check.R, on the same anchor-off solutions.
## No optimizer; runs in seconds.
##
## Test 1 (decisive): was the low-frequency cut NEEDED?
##   "HF only" = the 0 dB-floor solution's 250/500/1000 Hz gains with the
##   -10 dB solution's 2/4/8 kHz gains. It satisfies the 0 dB floor, and it
##   scores higher than the 0 dB solution. The 0 dB optimizer should therefore
##   have found it, unless it breaks the loudness cap.
##     - HF-only loudness ABOVE the cap -> the low-frequency cut was needed to
##       fit the high-frequency gain: a genuine loudness-budget effect.
##     - HF-only loudness AT/BELOW the cap -> the 0 dB optimizer missed a
##       feasible, better solution: the floor effect for that case is a
##       convergence artifact.
##
## Test 2 (secondary): why was the rest of the budget left unspent?
##   Starting from the -10 dB solution, add +3 dB at 2, 4 and 8 kHz in turn and
##   report the SII and loudness change. If the SII stops rising while budget
##   remains, extra high-frequency gain simply has no SII value. Li (level
##   distortion) and Ki (audibility) in the 4-6 kHz bands show which limit binds.
##
## Run from the repo root:
##   source("reproducibility_scripts/budget_check.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")

hl <- c(250, 500, 1000, 2000, 4000, 8000)
sp <- build_opennl_speech(hl, 65)
gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")

CASES <- list(
  e1500_s20 = c(10, 10, 10, 18.30075, 38.30075, 58.30075),
  e2000_s20 = c(10, 10, 10, 10.00000, 30.00000, 50.00000),
  e2000_s30 = c(10, 10, 10, 10.00000, 40.00000, 70.00000),
  a4        = c( 0,  0, 10, 40,       70,       80))

a <- read.csv("reproducibility_scripts/output/isoloudness/anchor_off_starts20.csv",
              stringsAsFactors = FALSE)
row_of  <- function(p, f) a[a$profile == p & a$floor == f, ]
gain_of <- function(p, f) as.numeric(row_of(p, f)[, gcols])

sii_of <- function(th, gv, des) {
  tg <- build_target(hl, sp, th, rep(0, 6), gv, 65)
  SII::sii(speech = tg$orig_speech, noise = rep(-50, 6), threshold = th,
           loss = rep(0, 6), freq = hl, prescription = tg, interpolate = TRUE,
           nal_ldf = FALSE, desensitization = des, desensitization_scale = 1)
}
loud_of <- function(th, gv) loudness_of(65, gv, th, rep(0, 6))$total

cat("\n==== Test 1: does the HF-only solution fit under the cap? ====\n")
cat("  (loudness from loudness_of(); compare each row with the floor-0 row,\n")
cat("   which the optimizer placed at the cap)\n")
for (nm in names(CASES)) {
  th <- CASES[[nm]]; g0 <- gain_of(nm, 0); g10 <- gain_of(nm, -10)
  hf <- c(g0[1:3], g10[4:6])
  cap <- row_of(nm, 0)$cap
  L0 <- loud_of(th, g0); Lhf <- loud_of(th, hf); L10 <- loud_of(th, g10)
  cat(sprintf("\n  %s   cap %.3f\n", nm, cap))
  cat(sprintf("    floor 0     %.3f sones   smoothed SII %.4f\n", L0,  sii_of(th, g0, "johnson2011_smoothed")$sii))
  cat(sprintf("    HF only     %.3f sones   smoothed SII %.4f   excess over floor-0: %+.3f\n",
              Lhf, sii_of(th, hf, "johnson2011_smoothed")$sii, Lhf - L0))
  cat(sprintf("    floor -10   %.3f sones   smoothed SII %.4f\n", L10, sii_of(th, g10, "johnson2011_smoothed")$sii))
  cat(sprintf("    verdict: %s\n", if (Lhf - L0 > 0.001)
      "HF-only breaks the cap -> low-frequency cut was needed (budget effect)"
    else "HF-only fits -> 0 dB optimizer missed a feasible better solution (artifact)"))
}

cat("\n\n==== Test 2: value of extra high-frequency gain on the -10 dB solution ====\n")
for (nm in names(CASES)) {
  th <- CASES[[nm]]; g10 <- gain_of(nm, -10)
  cap <- row_of(nm, 0)$cap
  base_s <- sii_of(th, g10, "johnson2011_smoothed")$sii
  base_a <- sii_of(th, g10, "none")$sii
  base_L <- loud_of(th, g10)
  cat(sprintf("\n  %s   budget left: %.3f sones\n", nm, cap - base_L))
  for (k in 4:6) {
    g <- g10; g[k] <- g[k] + 3
    cat(sprintf("    +3 dB at %4d Hz: d smoothed %+.4f  d ANSI %+.4f  d loudness %+.3f\n",
                hl[k], sii_of(th, g, "johnson2011_smoothed")$sii - base_s,
                sii_of(th, g, "none")$sii - base_a, loud_of(th, g) - base_L))
  }
  tb <- as.data.frame(sii_of(th, g10, "johnson2011_smoothed")$table, check.names = FALSE)
  sel <- tb$Fi >= 3400 & tb$Fi <= 7000
  print(data.frame(Fi = tb$Fi[sel], Li = round(tb$Li[sel], 3),
                   Ki = round(tb$Ki[sel], 3), Ai = round(tb$Ai[sel], 3)),
        row.names = FALSE)
}
