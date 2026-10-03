## rebuild_isoloudness.R ------------------------------------------------------
## Rebuilds the floor contrast without the rectification.
##
## open_nl() runs the whole optimization twice when vent_floor < 0 (lines
## 381-395 and 404-418) and returns whichever branch has the higher raw SII.
## That makes the published statistic max(0, SII_-10 - SII_0). This script
## disables the double-run in an in-memory copy, so each floor is optimized
## once, at the floor requested, and the two are reported side by side rather
## than differenced.
##
## Outputs: a printed table, plus a CSV for plotting.
## Runtime: 16 audiograms x 4 budgets x 2 floors = 128 optimizations,
## roughly 45 minutes. Nothing else should be running.
##
## If it errors partway, run  sink()  once at the prompt.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

STARTS    <- 3      # pin this; it changes the anchor shrinkage and so the SII
DESENS    <- 1.0    # widen to c(0, 0.5, 1) to cover the full design (x3 runtime)
BUDGETS   <- c(0.5, 1, 2, 3)
EVAL_LVL  <- 65

out_dir <- file.path("reproducibility_scripts", "output", "isoloudness")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(out_dir, sprintf("rebuild_isoloudness_%s.log", Sys.Date()))
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("rebuild_isoloudness.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("starts %d | desensitization %s\n\n", STARTS, paste(DESENS, collapse = ",")))

ns       <- asNamespace("SII")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

## Audiograms transcribed from gen_audiogram_family.log.
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

## ---- Build a copy of open_nl() with the double-run disabled ---------------

src <- readLines("R/open_nl.R")
ok <- grepl("if \\(vent_floor < 0\\)", src[381]) &&
      grepl("if \\(vent_floor < 0\\)", src[404]) &&
      grepl("loudness_sones > dynamic_cap", src[256]) &&
      grepl("^\\s*\\}\\s*$", src[259])
if (!ok) {
  cat("ANCHOR CHECK FAILED at lines 256/259/381/404:\n")
  for (i in c(256, 259, 381, 404)) cat(sprintf("%5d | %s\n", i, src[i]))
  sink(); stop("Aborting: re-anchor against the current R/open_nl.R.")
}
cat("anchor check passed (256, 259, 381, 404)\n")

## Force the else branch at both sites: optimize once, at the floor requested.
src[381] <- sub("if \\(vent_floor < 0\\)", "if (FALSE)", src[381])
src[404] <- sub("if \\(vent_floor < 0\\)", "if (FALSE)", src[404])

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
cat("double-run disabled: each floor optimized once at the floor requested\n\n")

## ---- Run ------------------------------------------------------------------

options(open_nl_starts = STARTS)
sp <- build_opennl_speech(hl_freqs, EVAL_LVL)

rows <- list()
for (ds in DESENS) {
  for (nm in rownames(FAMILY)) {
    htl6 <- FAMILY[nm, ]
    l0 <- loudness_of(EVAL_LVL, rep(0, 6), htl6, rep(0, 6))$total
    for (b in BUDGETS) {
      for (fl in c(0, -10)) {
        .open_nl_dbg$last_loud <- NULL
        g <- open_nl_single(speech = EVAL_LVL, threshold = htl6, freq = hl_freqs,
                            loss = rep(0, 6), cap_override = l0 + b,
                            vent_floor = fl, desensitization_scale = ds)$gain
        s <- report_sii(build_target(hl_freqs, sp, htl6, rep(0, 6), g, EVAL_LVL),
                        "johnson2011_smoothed", desensitization_scale = ds)
        ll <- .open_nl_dbg$final_loud
        rows[[length(rows) + 1]] <- data.frame(
          audiogram = nm,
          edge  = as.numeric(sub("^e(\\d+)_s\\d+$", "\\1", nm)),
          slope = as.numeric(sub("^e\\d+_s(\\d+)$", "\\1", nm)),
          desens = ds, budget = b, floor = fl,
          L0 = l0, cap = if (is.null(ll)) NA_real_ else ll[["cap"]],
          sones = if (is.null(ll)) NA_real_ else ll[["sones"]],
          sii = s,
          g250 = g[1], g500 = g[2], g1000 = g[3],
          g2000 = g[4], g4000 = g[5], g8000 = g[6],
          n_neg = sum(g < -0.001),
          neg_bands = paste(hl_freqs[g < -0.001], collapse = "/"),
          stringsAsFactors = FALSE)
        cat(sprintf("  %-10s ds%.1f b%.1f fl%+3d  sones %7.3f / cap %7.3f  SII %.4f\n",
                    nm, ds, b, fl,
                    if (is.null(ll)) NA_real_ else ll[["sones"]],
                    if (is.null(ll)) NA_real_ else ll[["cap"]], s))
      }
    }
  }
}
df <- do.call(rbind, rows)

csv_path <- file.path(out_dir, sprintf("isoloudness_%s.csv", Sys.Date()))
write.csv(df, csv_path, row.names = FALSE)

## ---- Paired summary: is the comparison iso-loudness? ----------------------

cat("\n\n==== Paired contrast, floor -10 vs floor 0 ====\n")
cat("   d_sones near zero means the two solutions are at the same loudness,\n")
cat("   so d_SII is a like-for-like efficiency difference.\n\n")
cat("  audiogram  ds   budget   sones0   sones-10   d_sones     SII0    SII-10    d_SII   neg bands (-10)   d_gain 2/4/8k\n")

for (ds in DESENS) for (nm in rownames(FAMILY)) for (b in BUDGETS) {
  a <- df[df$audiogram == nm & df$desens == ds & df$budget == b & df$floor ==   0, ]
  z <- df[df$audiogram == nm & df$desens == ds & df$budget == b & df$floor == -10, ]
  if (!nrow(a) || !nrow(z)) next
  dg <- c(z$g2000 - a$g2000, z$g4000 - a$g4000, z$g8000 - a$g8000)
  cat(sprintf("  %-10s %.1f  %5.1f  %8.3f %10.3f %+9.4f  %7.4f %8.4f %+8.4f   %-16s %s\n",
              nm, ds, b, a$sones, z$sones, z$sones - a$sones,
              a$sii, z$sii, z$sii - a$sii,
              ifelse(nzchar(z$neg_bands), z$neg_bands, "none"),
              paste(sprintf("%+.1f", dg), collapse = " ")))
}

## ---- Monotonicity in budget -----------------------------------------------

cat("\n\n==== SII as a function of budget (should be non-decreasing) ====\n\n")
for (ds in DESENS) for (fl in c(0, -10)) for (nm in rownames(FAMILY)) {
  v <- df[df$audiogram == nm & df$desens == ds & df$floor == fl, ]
  v <- v[order(v$budget), ]
  flag <- if (any(diff(v$sii) < -1e-6)) "  <-- NON-MONOTONE" else ""
  cat(sprintf("  %-10s ds%.1f fl%+3d  %s%s\n", nm, ds, fl,
              paste(sprintf("%.4f", v$sii), collapse = "  "), flag))
}

cat(sprintf("\n\ncsv written to: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
options(open_nl_starts = 3); rm(open_nl_single)
sink()
