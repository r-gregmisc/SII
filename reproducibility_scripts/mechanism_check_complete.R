## mechanism_check_complete.R -----------------------------------------------------
## Where does the floor effect come from, and why is budget left unspent?
## Replaces masking_check.R and budget_check.R for the complete-SII objective.
## No optimizer: rescores stored solutions from rerun_complete_objective.R.
## Runs in well under a minute.
##
## Part 1, source of the benefit, for the cases with a real complete-SII floor
## effect: the four 1000 Hz edge audiograms at the 0.5-sone budget and profiles
## A3 and A1 in the iso-loudness control (all anchor on). Each -10 dB solution is
## split into its low-frequency part (250-1000 Hz gains applied to the 0 dB
## solution, "LF cut only") and its high-frequency part (2000-8000 Hz gains
## applied to the 0 dB solution, "HF change only"). If the HF-only version scores
## like the -10 dB solution but is louder than the 0 dB solution (which sits at
## the cap), the low-frequency cut was needed to afford it: a budget effect.
## A band table shows which bands gained, and whether each is limited by
## masking (Zi > X'i) or by threshold.
##
## Part 2, unspent budget: the anchor-off 0.5-sone pairs whose -10 dB solution
## stopped well short of the cap. Adding 3 dB at 2, 4 and 8 kHz in turn shows
## whether any further gain would have raised the complete SII.
##
## Run from the repo root:
##   source("reproducibility_scripts/mechanism_check_complete.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

hl <- c(250, 500, 1000, 2000, 4000, 8000)
sp <- build_opennl_speech(hl, 65)
gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")
FAMILY <- rbind(
  e1000_s20 = c(10, 10, 10, 30.00000,  50.00000,  70.00000),
  e1000_s30 = c(10, 10, 10, 40.00000,  70.00000, 100.00000),
  e1000_s40 = c(10, 10, 10, 50.00000,  90.00000, 110.00000),
  e1000_s50 = c(10, 10, 10, 60.00000, 110.00000, 110.00000),
  e1500_s20 = c(10, 10, 10, 18.30075,  38.30075,  58.30075),
  e1500_s30 = c(10, 10, 10, 22.45112,  52.45112,  82.45112),
  e1500_s40 = c(10, 10, 10, 26.60150,  66.60150, 106.60150),
  e1500_s50 = c(10, 10, 10, 30.75187,  80.75187, 110.00000),
  e2000_s20 = c(10, 10, 10, 10.00000,  30.00000,  50.00000),
  e2000_s30 = c(10, 10, 10, 10.00000,  40.00000,  70.00000),
  e2000_s40 = c(10, 10, 10, 10.00000,  50.00000,  90.00000),
  e2000_s50 = c(10, 10, 10, 10.00000,  60.00000, 110.00000),
  e3000_s20 = c(10, 10, 10, 10.00000,  18.30075,  38.30075),
  e3000_s30 = c(10, 10, 10, 10.00000,  22.45112,  52.45112),
  e3000_s40 = c(10, 10, 10, 10.00000,  26.60150,  66.60150),
  e3000_s50 = c(10, 10, 10, 10.00000,  30.75187,  80.75187))

d <- read.csv("reproducibility_scripts/output/complete_objective/all_solutions.csv",
              stringsAsFactors = FALSE)
row_of <- function(set, anchor, profile, fl, budget = NA) {
  r <- d[d$set == set & d$anchor == anchor & d$profile == profile & d$floor == fl &
         (if (is.na(budget)) is.na(d$budget) else (!is.na(d$budget) & d$budget == budget)), ]
  if (!nrow(r)) stop(sprintf("no stored solution for %s %s %s floor %d", set, anchor, profile, fl))
  r[r$starts == max(r$starts), ][1, ]
}
case <- function(set, anchor, profile, budget = NA) {
  if (set == "sweep") { th <- FAMILY[profile, ]; loss <- rep(0, 6) }
  else { th <- jd2011_targets[[profile]]$threshold; loss <- rep(0, 6) }
  r0 <- row_of(set, anchor, profile, 0, budget); r10 <- row_of(set, anchor, profile, -10, budget)
  list(th = th, loss = loss, r0 = r0, r10 = r10,
       g0 = as.numeric(r0[, gcols]), g10 = as.numeric(r10[, gcols]))
}
sii_of <- function(cs, g, des) {
  tg <- build_target(hl, sp, cs$th, cs$loss, g, 65)
  SII::sii(speech = tg$orig_speech, noise = rep(-50, 6), threshold = cs$th, loss = cs$loss,
           freq = hl, prescription = tg, interpolate = TRUE, nal_ldf = FALSE,
           desensitization = des)
}
loud_of <- function(cs, g) loudness_of(65, g, cs$th, cs$loss)$total

cat("\n==== Part 1: source of the floor effect (anchor on) ====\n")
cat("complete / ANSI SII; loudness from loudness_of(); HF-only excess is relative\n")
cat("to the 0 dB solution, which the optimizer placed at the cap\n")
P1 <- list(list("sweep", "e1000_s20", 0.5), list("sweep", "e1000_s30", 0.5),
           list("sweep", "e1000_s40", 0.5), list("sweep", "e1000_s50", 0.5),
           list("iso", "a3", NA), list("iso", "a1", NA))
for (p in P1) {
  cs <- case(p[[1]], "on", p[[2]], p[[3]])
  lf <- c(cs$g10[1:3], cs$g0[4:6]); hf <- c(cs$g0[1:3], cs$g10[4:6])
  L0 <- loud_of(cs, cs$g0)
  cat(sprintf("\n  %s %s   gains 0 dB: %s\n              -10 dB: %s\n", p[[1]], p[[2]],
              paste(sprintf("%6.1f", cs$g0), collapse = ""), paste(sprintf("%6.1f", cs$g10), collapse = "")))
  base <- c(sii_of(cs, cs$g0, "johnson2011_complete")$sii, sii_of(cs, cs$g0, "none")$sii)
  for (lab in c("floor -10", "LF cut only", "HF change only")) {
    g <- switch(lab, "floor -10" = cs$g10, "LF cut only" = lf, "HF change only" = hf)
    s <- c(sii_of(cs, g, "johnson2011_complete")$sii, sii_of(cs, g, "none")$sii)
    cat(sprintf("    %-15s d complete %+.4f  d ANSI %+.4f   loudness vs 0 dB solution %+.3f sones\n",
                lab, s[1] - base[1], s[2] - base[2], loud_of(cs, g) - L0))
  }
  t0  <- as.data.frame(sii_of(cs, cs$g0,  "johnson2011_complete")$table, check.names = FALSE)
  t10 <- as.data.frame(sii_of(cs, cs$g10, "johnson2011_complete")$table, check.names = FALSE)
  dI  <- t10[["IiAi"]] - t0[["IiAi"]]
  mask <- t10[["Zi"]] > t10[["X'i"]]
  sel <- abs(dI) >= 0.001
  if (any(sel)) {
    cat("    bands with |d IiAi| >= 0.001 (complete SII):\n")
    print(data.frame(Fi = t0$Fi[sel], dIiAi = round(dI[sel], 4),
                     Ki_0 = round(t0$Ki[sel], 3), Ki_10 = round(t10$Ki[sel], 3),
                     limited_by = ifelse(mask[sel], "masking", "threshold")), row.names = FALSE)
  }
  cat(sprintf("    total d IiAi %+.4f, of which LF bands (<= 1000 Hz) %+.4f\n",
              sum(dI), sum(dI[t0$Fi <= 1000])))
}

cat("\n\n==== Part 2: unspent budget, anchor off, 0.5 sone ====\n")
for (nm in c("e1500_s20", "e2000_s20", "e2000_s30", "e3000_s40")) {
  cs <- case("sweep", "off", nm, 0.5)
  left <- cs$r10$cap - cs$r10$sones_opt
  b_c <- sii_of(cs, cs$g10, "johnson2011_complete")$sii; b_a <- sii_of(cs, cs$g10, "none")$sii
  b_L <- loud_of(cs, cs$g10)
  cat(sprintf("\n  %s   floor effect: complete %+.4f  ANSI %+.4f   budget left at -10 dB: %.3f sones\n",
              nm, cs$r10$sii_complete - cs$r0$sii_complete, cs$r10$sii_ansi - cs$r0$sii_ansi, left))
  for (k in 4:6) {
    g <- cs$g10; g[k] <- g[k] + 3
    cat(sprintf("    +3 dB at %4d Hz: d complete %+.4f  d ANSI %+.4f  d loudness %+.3f\n", hl[k],
                sii_of(cs, g, "johnson2011_complete")$sii - b_c,
                sii_of(cs, g, "none")$sii - b_a, loud_of(cs, g) - b_L))
  }
}
cat("\nDone. Paste all output to Claude.\n")
