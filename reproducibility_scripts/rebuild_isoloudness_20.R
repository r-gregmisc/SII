## rebuild_isoloudness_20.R --------------------------------------------------
## Full audiogram-family rebuild at 20 multi-starts.
##
## The 3-start run (2026-09-18) under-converged the floor-0 side: in five of
## six probed cells the negative d_SII came from SII0 being overstated, and it
## collapsed once restarts rose. Every number in that run therefore needs
## redoing at a restart count where the floor-0 branch has converged.
##
## As before, open_nl()'s double-run (lines 381-395, 404-418) is disabled in an
## in-memory copy so each floor is optimized once, at the floor requested, and
## the two are reported side by side rather than differenced.
##
## Runtime: 128 optimizations x 20 starts, roughly 5-7 hours. Nothing else
## should be running. Results are written to CSV after every cell, and the
## script RESUMES from that CSV if restarted, so a crash or an interrupt costs
## only the cell in progress.
##
## If it errors partway, run  sink()  once at the prompt, then source it again
## to pick up where it stopped.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

STARTS   <- 20
DESENS   <- 1.0
BUDGETS  <- c(0.5, 1, 2, 3)
EVAL_LVL <- 65

out_dir <- file.path("reproducibility_scripts", "output", "isoloudness")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(out_dir, sprintf("isoloudness_starts%d.csv", STARTS))
log_path <- file.path(out_dir, sprintf("rebuild_isoloudness_starts%d_%s.log",
                                       STARTS, Sys.Date()))
con <- file(log_path, open = "at"); sink(con, split = TRUE)

cat("\nrebuild_isoloudness_20.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("starts %d | desensitization %s | open_nl_maxit %s\n\n",
            STARTS, paste(DESENS, collapse = ","),
            getOption("open_nl_maxit", "unset")))

ns       <- asNamespace("SII")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

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

## ---- in-memory copy: double-run disabled, loudness logged ----------------

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
cat("anchor check passed (256, 259, 325)\n")

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
cat("each floor optimized once at the floor requested\n")

## ---- resume from any existing CSV ----------------------------------------

done <- if (file.exists(csv_path)) {
  d <- read.csv(csv_path, stringsAsFactors = FALSE)
  cat(sprintf("resuming: %d of 128 runs already in %s\n", nrow(d), basename(csv_path)))
  d
} else {
  cat("starting fresh\n")
  NULL
}
key_done <- if (is.null(done)) character(0) else
  paste(done$audiogram, done$desens, done$budget, done$floor)

options(open_nl_starts = STARTS)
sp <- build_opennl_speech(hl_freqs, EVAL_LVL)

n_total <- length(rownames(FAMILY)) * length(DESENS) * length(BUDGETS) * 2
t_start <- Sys.time(); n_new <- 0
cat(sprintf("\n%d runs to do\n\n", n_total - length(key_done)))

for (ds in DESENS) {
  for (nm in rownames(FAMILY)) {
    htl6 <- FAMILY[nm, ]
    l0 <- loudness_of(EVAL_LVL, rep(0, 6), htl6, rep(0, 6))$total
    for (b in BUDGETS) {
      for (fl in c(0, -10)) {

        key <- paste(nm, ds, b, fl)
        if (key %in% key_done) next

        .open_nl_dbg$last_loud <- NULL
        g <- open_nl_single(speech = EVAL_LVL, threshold = htl6, freq = hl_freqs,
                            loss = rep(0, 6), cap_override = l0 + b,
                            vent_floor = fl, desensitization_scale = ds)$gain
        s <- report_sii(build_target(hl_freqs, sp, htl6, rep(0, 6), g, EVAL_LVL),
                        "johnson2011_smoothed", desensitization_scale = ds)
        ll <- .open_nl_dbg$final_loud

        row <- data.frame(
          audiogram = nm,
          edge  = as.numeric(sub("^e(\\d+)_s\\d+$", "\\1", nm)),
          slope = as.numeric(sub("^e\\d+_s(\\d+)$", "\\1", nm)),
          desens = ds, budget = b, floor = fl, starts = STARTS,
          L0 = l0, cap = if (is.null(ll)) NA_real_ else ll[["cap"]],
          sones = if (is.null(ll)) NA_real_ else ll[["sones"]],
          sii = s,
          g250 = g[1], g500 = g[2], g1000 = g[3],
          g2000 = g[4], g4000 = g[5], g8000 = g[6],
          n_neg = sum(g < -0.001),
          neg_bands = paste(hl_freqs[g < -0.001], collapse = "/"),
          stringsAsFactors = FALSE)

        ## append immediately so an interrupt costs one cell, not the run
        write.table(row, csv_path, sep = ",", row.names = FALSE,
                    col.names = !file.exists(csv_path), append = file.exists(csv_path))

        n_new <- n_new + 1
        el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
        rem <- (n_total - length(key_done) - n_new) * el / n_new
        cat(sprintf("  [%3d/%3d] %-10s b%.1f fl%+3d  sones %7.3f/%7.3f  SII %.4f   %.0fm elapsed, ~%.0fm left\n",
                    n_new + length(key_done), n_total, nm, b, fl,
                    if (is.null(ll)) NA_real_ else ll[["sones"]],
                    if (is.null(ll)) NA_real_ else ll[["cap"]], s, el, rem))
      }
    }
  }
}

df <- read.csv(csv_path, stringsAsFactors = FALSE)

## ---- paired contrast ------------------------------------------------------

cat("\n\n==== Paired contrast, floor -10 vs floor 0 ====\n")
cat("   iso? marks |d_sones| <= 0.001, where d_SII is a like-for-like\n")
cat("   efficiency difference at matched loudness.\n\n")
cat("  audiogram  budget   sones0  sones-10   d_sones     SII0   SII-10    d_SII  iso?  neg bands (-10)   d_gain 2/4/8k\n")

for (ds in DESENS) for (nm in rownames(FAMILY)) for (b in BUDGETS) {
  a <- df[df$audiogram == nm & df$desens == ds & df$budget == b & df$floor ==   0, ]
  z <- df[df$audiogram == nm & df$desens == ds & df$budget == b & df$floor == -10, ]
  if (!nrow(a) || !nrow(z)) next
  dsn <- z$sones - a$sones
  dg <- c(z$g2000 - a$g2000, z$g4000 - a$g4000, z$g8000 - a$g8000)
  cat(sprintf("  %-10s %5.1f %8.3f %9.3f %+9.4f %8.4f %8.4f %+8.4f  %-4s  %-16s %s\n",
              nm, b, a$sones, z$sones, dsn, a$sii, z$sii, z$sii - a$sii,
              if (abs(dsn) <= 0.001) "yes" else "NO",
              ifelse(nzchar(z$neg_bands), z$neg_bands, "none"),
              paste(sprintf("%+.1f", dg), collapse = " ")))
}

## ---- negatives: the remaining noise floor --------------------------------

cat("\n\n==== Negative d_SII at iso-loudness (impossible; = optimizer noise) ====\n\n")
neg <- 0
for (ds in DESENS) for (nm in rownames(FAMILY)) for (b in BUDGETS) {
  a <- df[df$audiogram == nm & df$desens == ds & df$budget == b & df$floor ==   0, ]
  z <- df[df$audiogram == nm & df$desens == ds & df$budget == b & df$floor == -10, ]
  if (!nrow(a) || !nrow(z)) next
  d <- z$sii - a$sii
  if (d < 0 && abs(z$sones - a$sones) <= 0.001) {
    cat(sprintf("  %-10s b%.1f  d_SII %+.4f\n", nm, b, d)); neg <- max(neg, abs(d))
  }
}
cat(sprintf("\n  largest: %.4f  <- the resolution limit to quote in Methods\n", neg))

## ---- monotonicity in budget ----------------------------------------------

cat("\n\n==== SII as a function of budget (should be non-decreasing) ====\n\n")
for (ds in DESENS) for (fl in c(0, -10)) for (nm in rownames(FAMILY)) {
  v <- df[df$audiogram == nm & df$desens == ds & df$floor == fl, ]
  v <- v[order(v$budget), ]
  if (!nrow(v)) next
  flag <- if (any(diff(v$sii) < -1e-6)) "  <-- NON-MONOTONE" else ""
  cat(sprintf("  %-10s fl%+3d  %s%s\n", nm, fl,
              paste(sprintf("%.4f", v$sii), collapse = "  "), flag))
}

cat(sprintf("\n\ncsv: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
options(open_nl_starts = 3); rm(open_nl_single)
sink()
