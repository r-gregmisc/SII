## rerun_unmatched_tight_budget.R ----------------------------------------------
## Run 1 of 2. Re-optimizes the six audiogram-family pairs at the tightest
## loudness budget (0.5 sone) whose two floor solutions did not land on the
## same loudness in isoloudness_starts20_naldf_off.csv (desens = 1 rows).
##
## At a 0.5-sone budget the cap should bind for both floors. In five of the
## six pairs the -10 dB solution stops short of the cap, which suggests the
## larger search space did not converge in 20 starts. This script reruns both
## floors for those audiograms at 40 starts, optimized on the smoothed
## desensitized SII (desensitization_scale = 1), and scores each solution
## under smoothed, complete, and ANSI SII.
##
## The per-call seed in open_nl() depends only on the audiogram and level, so
## starts 1-20 here are identical to the original run and starts 21-40 are
## additional. The penalized objective can therefore only improve or stay the
## same. If a pair is STILL unmatched at 40 starts, the shortfall is probably a
## genuine optimum of the penalized objective (the anchor penalty making the
## remaining budget not worth spending), not a convergence failure. Run 2
## (anchor off) tests that directly.
##
## Runtime: 12 optimizations at 40 starts, roughly 60-90 minutes.
## Resumes from its CSV if interrupted. If it errors, run  sink()  once, then
## source it again.
##
## Run from the repo root:
##   source("reproducibility_scripts/rerun_unmatched_tight_budget.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")

STARTS   <- 40
DS       <- 1
BUDGET   <- 0.5
EVAL_LVL <- 65
AUDS     <- c("e1000_s40", "e1000_s50", "e1500_s30",
              "e2000_s20", "e3000_s40", "e3000_s50")

out_dir  <- file.path("reproducibility_scripts", "output", "isoloudness")
csv_path <- file.path(out_dir, sprintf("unmatched_tight_rerun_starts%d.csv", STARTS))
log_path <- file.path(out_dir, sprintf("unmatched_tight_rerun_starts%d_%s.log",
                                       STARTS, Sys.Date()))
old_csv  <- file.path(out_dir, "sweep_smoothed_rescored.csv")
if (!file.exists(old_csv))
  stop("Run rescore_sweep_smoothed.R first; this script compares against its output.")

con <- file(log_path, open = "at"); sink(con, split = TRUE)
cat("\nrerun_unmatched_tight_budget.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("starts %d | desensitization_scale %g | budget %g | open_nl_maxit %s\n\n",
            STARTS, DS, BUDGET, getOption("open_nl_maxit", "unset")))

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

## Audiograms, identical to rebuild_isoloudness_20_naldf_off.R
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

## ---- in-memory copy: double-run disabled, loudness and objective logged ----
## Same patches as rebuild_isoloudness_20_naldf_off.R, so the logged loudness
## is the optimizer's own and is directly comparable with the original CSV.

ns  <- asNamespace("SII")
## The vent_floor dual-run branch has been removed from R/open_nl.R, so each
## floor is optimized once at the floor requested without patching.
src <- readLines("R/open_nl.R")
ok <- grepl("loudness_sones > dynamic_cap", src[256]) &&
      grepl("^\\s*\\}\\s*$", src[259]) &&
      grepl("^\\s*\\}\\s*$", src[325])
if (!ok) {
  cat("ANCHOR CHECK FAILED at 256/259/325:\n")
  for (i in c(256, 259, 325)) cat(sprintf("%5d | %s\n", i, src[i]))
  sink(); stop("Aborting: re-anchor against the current R/open_nl.R.")
}
.open_nl_dbg <- new.env(parent = emptyenv())
src <- append(src, paste(
  '      .open_nl_dbg$final_obj  <- obj_fn(best_shifts)',
  '      .open_nl_dbg$final_loud <- .open_nl_dbg$last_loud',
  sep = "\n"), after = 325)
src <- append(src,
  '          .open_nl_dbg$last_loud <- c(sones = loudness_sones, cap = dynamic_cap)',
  after = 259)
tmp <- tempfile(fileext = ".R"); writeLines(src, tmp)
e <- new.env(parent = ns); sys.source(tmp, envir = e)
open_nl_single <- e$open_nl; environment(open_nl_single) <- ns
cat("anchor check passed; loudness logging on\n\n")

## ---- run ------------------------------------------------------------------

done <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors = FALSE) else NULL
key_done <- if (is.null(done)) character(0) else paste(done$audiogram, done$floor)
if (length(key_done)) cat(sprintf("resuming: %d of %d already done\n", length(key_done),
                                  2 * length(AUDS)))

options(open_nl_starts = STARTS)
sp <- build_opennl_speech(hl_freqs, EVAL_LVL)
t_start <- Sys.time(); n_new <- 0

for (nm in AUDS) {
  htl6 <- FAMILY[nm, ]
  l0   <- loudness_of(EVAL_LVL, rep(0, 6), htl6, rep(0, 6))$total
  for (fl in c(0, -10)) {
    if (paste(nm, fl) %in% key_done) next
    .open_nl_dbg$last_loud <- NULL; .open_nl_dbg$final_obj <- NA_real_
    g <- open_nl_single(speech = EVAL_LVL, threshold = htl6, freq = hl_freqs,
                        loss = rep(0, 6), cap_override = l0 + BUDGET,
                        vent_floor = fl, desensitization_scale = DS)$gain
    tgt <- build_target(hl_freqs, sp, htl6, rep(0, 6), g, EVAL_LVL)
    ll  <- .open_nl_dbg$final_loud
    row <- data.frame(
      audiogram = nm,
      edge  = as.numeric(sub("^e(\\d+)_s\\d+$", "\\1", nm)),
      slope = as.numeric(sub("^e\\d+_s(\\d+)$", "\\1", nm)),
      budget = BUDGET, floor = fl, starts = STARTS,
      cap   = if (is.null(ll)) NA_real_ else ll[["cap"]],
      sones = if (is.null(ll)) NA_real_ else ll[["sones"]],
      objective = -.open_nl_dbg$final_obj,
      sii_smooth   = report_sii(tgt, "johnson2011_smoothed", desensitization_scale = 1),
      sii_complete = report_sii(tgt, "johnson2011_complete", desensitization_scale = 1),
      sii_ansi     = report_sii(tgt, "none"),
      g250 = g[1], g500 = g[2], g1000 = g[3], g2000 = g[4], g4000 = g[5], g8000 = g[6],
      stringsAsFactors = FALSE)
    write.table(row, csv_path, sep = ",", row.names = FALSE,
                col.names = !file.exists(csv_path), append = file.exists(csv_path))
    n_new <- n_new + 1
    el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
    cat(sprintf("  %-10s fl%+3d  sones %7.3f / cap %7.3f  smoothed SII %.4f   %.0fm elapsed\n",
                nm, fl, row$sones, row$cap, row$sii_smooth, el))
  }
}

## ---- compare with the 20-start solutions ----------------------------------

new <- read.csv(csv_path, stringsAsFactors = FALSE)
old <- read.csv(old_csv, stringsAsFactors = FALSE)
old <- old[old$budget == BUDGET, ]

pair_of <- function(d, nm, s_col) {
  a <- d[d$audiogram == nm & d$floor == 0, ]; z <- d[d$audiogram == nm & d$floor == -10, ]
  c(d_sones = z$sones - a$sones,
    d_smooth = z[[s_col[1]]] - a[[s_col[1]]],
    d_complete = z[[s_col[2]]] - a[[s_col[2]]],
    d_ansi = z[[s_col[3]]] - a[[s_col[3]]])
}
cols <- c("sii_smooth", "sii_complete", "sii_ansi")

cat("\n\n==== Per audiogram: 20 starts (old) vs 40 starts (new) ====\n")
cat("  audiogram    d_sones old/new     smoothed old/new    complete old/new     ANSI old/new   matched now?\n")
for (nm in AUDS) {
  o <- pair_of(old, nm, cols); n <- pair_of(new, nm, cols)
  cat(sprintf("  %-10s  %+7.3f / %+7.3f   %+.4f / %+.4f   %+.4f / %+.4f   %+.4f / %+.4f   %s\n",
              nm, o[1], n[1], o[2], n[2], o[3], n[3], o[4], n[4],
              if (abs(n[1]) <= 0.001) "yes" else "NO"))
}

## Merge: replace the six audiograms' budget-0.5 pairs with the 40-start runs.
merged <- rbind(old[!old$audiogram %in% AUDS, c("audiogram", "edge", "floor", "sones", cols)],
                new[, c("audiogram", "edge", "floor", "sones", cols)])
pairs <- do.call(rbind, lapply(unique(merged$audiogram), function(nm) {
  p <- pair_of(merged, nm, cols)
  data.frame(audiogram = nm, edge = merged$edge[merged$audiogram == nm][1], t(p))
}))
pairs$matched <- abs(pairs$d_sones) <= 0.001

cat(sprintf("\n\n==== Tightest budget after merge: %d of 16 pairs matched ====\n",
            sum(pairs$matched)))
cat("\nAll pairs, mean floor effect by edge:\n")
print(round(aggregate(cbind(d_smooth, d_complete, d_ansi) ~ edge, data = pairs, FUN = mean), 4))
if (any(pairs$matched)) {
  cat("\nMatched pairs only:\n")
  print(round(aggregate(cbind(d_smooth, d_complete, d_ansi) ~ edge,
                        data = pairs[pairs$matched, ], FUN = mean), 4))
  print(table(edge = pairs$edge[pairs$matched]))
}
write.csv(pairs, file.path(out_dir, "tight_budget_pairs_merged.csv"), row.names = FALSE)

cat(sprintf("\ncsv: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
options(open_nl_starts = 3); rm(open_nl_single)
sink()
