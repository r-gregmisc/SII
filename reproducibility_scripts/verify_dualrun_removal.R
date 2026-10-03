## verify_dualrun_removal.R ----------------------------------------------------
## Confirms that removing the vent_floor dual-run branch from open_nl() leaves
## results unchanged relative to the patched in-memory copy the JAAA analysis
## scripts used (lines 381 and 404 set to `if (FALSE)`).
##
## Compares gains from the current package against that patched copy of the
## pre-removal file for two profiles, two levels (65 and 80 dB SPL) and both
## floors. Every line should read "identical". Uses 3 restarts; a few minutes.
##
## Run from the repository root:
##   source("reproducibility_scripts/verify_dualrun_removal.R")
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
ns <- asNamespace("SII")

old <- readLines("scratch/open_nl_pre_dualrun_removal.R")
stopifnot(grepl("if \\(vent_floor < 0\\)", old[381]),
          grepl("if \\(vent_floor < 0\\)", old[404]))
old[381] <- sub("if \\(vent_floor < 0\\)", "if (FALSE)", old[381])
old[404] <- sub("if \\(vent_floor < 0\\)", "if (FALSE)", old[404])
tmp <- tempfile(fileext = ".R"); writeLines(old, tmp)
e <- new.env(parent = ns); sys.source(tmp, envir = e)
open_nl_patched <- e$open_nl; environment(open_nl_patched) <- ns

options(open_nl_starts = 3)
hl <- c(250, 500, 1000, 2000, 4000, 8000)
cases <- list(A3 = c(10, 20, 40, 50, 55, 60),
              A4 = c( 0,  0, 10, 40, 70, 80))

n_diff <- 0
for (nm in names(cases)) for (lev in c(65, 80)) for (fl in c(0, -10)) {
  args <- list(speech = lev, threshold = cases[[nm]], freq = hl,
               loss = rep(0, 6), vent_floor = fl)
  a <- do.call(open_nl, args)$gain
  b <- do.call(open_nl_patched, args)$gain
  same <- identical(a, b)
  if (!same) n_diff <- n_diff + 1
  cat(sprintf("%s  %d dB SPL  floor %3d dB: %s\n", nm, lev, fl,
              if (same) "identical"
              else sprintf("DIFFERENT (max |diff| %.3g dB)", max(abs(a - b)))))
}
cat(if (n_diff == 0) "\nAll cases identical: the fix does not change any result.\n"
    else sprintf("\n%d case(s) differ -- do not rely on the fix until resolved.\n", n_diff))
