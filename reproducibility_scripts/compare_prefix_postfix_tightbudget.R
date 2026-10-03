## compare_prefix_postfix_tightbudget.R -----------------------------------------
## Directly tests whether removing the vent_floor dual-run branch changed any
## already-reported number, by running the SAME six tight-budget audiogram
## pairs used in rerun_unmatched_tight_budget.R through both:
##   (a) the ORIGINAL code with the dual-run branch ACTIVE (unpatched copy of
##       scratch/open_nl_pre_dualrun_removal.R) -- this is what generated the
##       numbers currently reported in the manuscript/supplement, and
##   (b) the CURRENT fixed R/open_nl.R (single run at the requested floor).
##
## Unlike verify_dualrun_removal.R (which patches the branch OFF in both
## copies, and so only checks that the refactor didn't break the surviving
## code path), this script leaves the bug switched ON in (a). If the bug ever
## changed a reported number, it will show up here as a gain/loudness/SII
## difference at floor = -10 dB (the branch is only reachable when
## vent_floor < 0; floor = 0 is included as a same-either-way control).
##
## Runtime: 12 optimizations at 20 starts (matches the original run), a few
## minutes.
##
## Run from the repo root:
##   source("reproducibility_scripts/compare_prefix_postfix_tightbudget.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")   # loads current (fixed) SII package

ns <- asNamespace("SII")

## ---- build the ORIGINAL open_nl(), dual-run branch left ACTIVE ------------
old <- readLines("scratch/open_nl_pre_dualrun_removal.R")
stopifnot(grepl("if \\(vent_floor < 0\\)", old[381]),
          grepl("if \\(vent_floor < 0\\)", old[404]))
e_old <- new.env(parent = ns)
sys.source("scratch/open_nl_pre_dualrun_removal.R", envir = e_old)
open_nl_old_active <- e_old$open_nl
environment(open_nl_old_active) <- ns
cat("original (buggy, dual-run active) open_nl() loaded from scratch/\n")
cat("current (fixed) open_nl() loaded via devtools::load_all\n\n")

## ---- same six audiograms / same budget as the tight-budget rerun ----------
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
STARTS   <- 20
DS       <- 1
BUDGET   <- 0.5
EVAL_LVL <- 65
AUDS <- c("e1000_s40", "e1000_s50", "e1500_s30",
          "e2000_s20", "e3000_s40", "e3000_s50")

FAMILY <- rbind(
  e1000_s40 = c(10, 10, 10, 50.00000,  90.00000, 110.00000),
  e1000_s50 = c(10, 10, 10, 60.00000, 110.00000, 110.00000),
  e1500_s30 = c(10, 10, 10, 22.45112,  52.45112,  82.45112),
  e2000_s20 = c(10, 10, 10, 10.00000,  30.00000,  50.00000),
  e3000_s40 = c(10, 10, 10, 10.00000,  26.60150,  66.60150),
  e3000_s50 = c(10, 10, 10, 10.00000,  30.75187,  80.75187))

options(open_nl_starts = STARTS)

rows <- list()
for (nm in AUDS) {
  htl6 <- FAMILY[nm, ]
  l0  <- loudness_of(EVAL_LVL, rep(0, 6), htl6, rep(0, 6))$total
  cap <- l0 + BUDGET
  for (fl in c(-10, 0)) {
    g_new <- open_nl(speech = EVAL_LVL, threshold = htl6, freq = hl_freqs,
                      loss = rep(0, 6), cap_override = cap,
                      vent_floor = fl, desensitization_scale = DS)$gain
    g_old <- open_nl_old_active(speech = EVAL_LVL, threshold = htl6, freq = hl_freqs,
                      loss = rep(0, 6), cap_override = cap,
                      vent_floor = fl, desensitization_scale = DS)$gain
    same <- isTRUE(all.equal(g_new, g_old, tolerance = 1e-8))
    maxdiff <- max(abs(g_new - g_old))
    rows[[length(rows) + 1]] <- data.frame(
      audiogram = nm, floor = fl, identical = same, max_gain_diff_dB = maxdiff)
    cat(sprintf("%-10s floor %+3d dB: %s (max |gain diff| %.4g dB)\n",
                nm, fl, if (same) "identical" else "DIFFERENT", maxdiff))
  }
}

result <- do.call(rbind, rows)
n_diff <- sum(!result$identical)
cat("\n")
print(result)
cat(sprintf("\n%s\n", if (n_diff == 0)
  "All cases identical: the fix did not change any of these already-reported results."
  else sprintf("%d case(s) DIFFER between the original (buggy) and current (fixed) code -- these are cases where the dual-run bug actually changed the answer. Re-derive the affected manuscript numbers from the fixed code before using them in a citable release.", n_diff)))

options(open_nl_starts = 3)
