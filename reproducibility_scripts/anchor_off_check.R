## anchor_off_check.R ---------------------------------------------------------
## Run 2 of 2. Tests whether the anchor penalty in Open-NL's objective is what
## keeps the floor effect small.
##
## The objective charges 0.1 points per dB of shift away from the heuristic
## prescription (R/open_nl.R line 268). Driving two low-frequency bands to
## -10 dB costs at least 0.02 SII-equivalent, the same size as the reported
## floor effects. This script sets that weight to 0 in an in-memory copy and
## re-optimizes, on the smoothed desensitized SII, in two parts:
##
##   A. the 16 audiogram-family profiles at the tightest budget (0.5 sone),
##      both floors (32 optimizations);
##   B. the Table 3 profiles A1-A5 at NAL-NL2's own achieved loudness, both
##      floors (10 optimizations). A6 and A7 are omitted: the floor never
##      engages for them.
##
## Every solution is scored under smoothed, complete, and ANSI SII, and the
## floor effects are printed beside the anchor-on values.
##
## Reading the result:
##   - floor effects about the same  -> the anchor is not suppressing the
##     benefit; the "small" conclusion stands.
##   - floor effects much larger     -> the reported values understate the
##     unpenalized benefit; the paper must report both.
## With the anchor off, only the tiny roughness term (0.001) regularizes the
## gain curve, so solutions may be jagged. Use them only for this comparison.
##
## Runtime: 42 optimizations at 20 starts, roughly 2.5 hours.
## Resumes from its CSV if interrupted. If it errors, run  sink()  once, then
## source it again.
##
## Run from the repo root (after rescore_sweep_smoothed.R):
##   source("reproducibility_scripts/anchor_off_check.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

STARTS   <- 20
DS       <- 1
BUDGET   <- 0.5
EVAL_LVL <- 65

out_dir  <- file.path("reproducibility_scripts", "output", "isoloudness")
csv_path <- file.path(out_dir, sprintf("anchor_off_starts%d.csv", STARTS))
log_path <- file.path(out_dir, sprintf("anchor_off_starts%d_%s.log", STARTS, Sys.Date()))
sweep_on <- if (file.exists(file.path(out_dir, "tight_budget_pairs_merged.csv")))
  file.path(out_dir, "tight_budget_pairs_merged.csv") else
  file.path(out_dir, "sweep_smoothed_rescored.csv")
table_on <- file.path("reproducibility_scripts", "output", "jaaa_audmod",
                      "table2_iso_loudness_v2.csv")
if (!file.exists(sweep_on) || !file.exists(table_on))
  stop("Missing anchor-on results. Run rescore_sweep_smoothed.R first.")

con <- file(log_path, open = "at"); sink(con, split = TRUE)
cat("\nanchor_off_check.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("starts %d | desensitization_scale %g | open_nl_maxit %s\n",
            STARTS, DS, getOption("open_nl_maxit", "unset")))
cat("anchor-on sweep comparison file:", sweep_on, "\n\n")

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

## ---- in-memory copy: anchor weight 0, double-run disabled, loudness logged --

ns  <- asNamespace("SII")
## The vent_floor dual-run branch has been removed from R/open_nl.R, so each
## floor is optimized once at the floor requested without patching.
src <- readLines("R/open_nl.R")
ok <- grepl("anchor_penalty <- sum\\(abs\\(shifts\\)\\) \\* 0\\.1", src[268]) &&
      grepl("loudness_sones > dynamic_cap", src[256]) &&
      grepl("^\\s*\\}\\s*$", src[259]) &&
      grepl("^\\s*\\}\\s*$", src[325])
if (!ok) {
  cat("ANCHOR CHECK FAILED at 256/259/268/325:\n")
  for (i in c(256, 259, 268, 325)) cat(sprintf("%5d | %s\n", i, src[i]))
  sink(); stop("Aborting: re-anchor against the current R/open_nl.R.")
}
src[268] <- sub("\\* 0\\.1", "* 0", src[268])
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
cat("anchor check passed\n")
cat("patched line 268:", trimws(src[268]), "\n")
cat("loudness logging on\n\n")

## ---- run ------------------------------------------------------------------

done <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors = FALSE) else NULL
key_done <- if (is.null(done)) character(0) else paste(done$part, done$profile, done$floor)
options(open_nl_starts = STARTS)

score_row <- function(part, profile, fl, g, tgt, cap, sones_opt, sones_model) {
  data.frame(part = part, profile = profile, floor = fl, starts = STARTS,
             cap = cap, sones_opt = sones_opt, sones_model = sones_model,
             sii_smooth   = report_sii(tgt, "johnson2011_smoothed"),
             sii_complete = report_sii(tgt, "johnson2011_complete"),
             sii_ansi     = report_sii(tgt, "none"),
             g250 = g[1], g500 = g[2], g1000 = g[3], g2000 = g[4], g4000 = g[5], g8000 = g[6],
             stringsAsFactors = FALSE)
}
save_row <- function(row) write.table(row, csv_path, sep = ",", row.names = FALSE,
                                      col.names = !file.exists(csv_path),
                                      append = file.exists(csv_path))
t_start <- Sys.time(); n_new <- 0
progress <- function(row) {
  n_new <<- n_new + 1
  el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  cat(sprintf("  %s %-10s fl%+3d  sones %7.3f / cap %7.3f  smoothed SII %.4f  g250/500 %+.1f/%+.1f  %.0fm\n",
              row$part, row$profile, row$floor, row$sones_opt, row$cap,
              row$sii_smooth, row$g250, row$g500, el))
}

## Part A: audiogram family, tightest budget
sp <- build_opennl_speech(hl_freqs, EVAL_LVL)
for (nm in rownames(FAMILY)) {
  htl6 <- FAMILY[nm, ]
  l0   <- loudness_of(EVAL_LVL, rep(0, 6), htl6, rep(0, 6))$total
  for (fl in c(0, -10)) {
    if (paste("A", nm, fl) %in% key_done) next
    .open_nl_dbg$last_loud <- NULL
    g <- open_nl_single(speech = EVAL_LVL, threshold = htl6, freq = hl_freqs,
                        loss = rep(0, 6), cap_override = l0 + BUDGET,
                        vent_floor = fl, desensitization_scale = DS)$gain
    ll  <- .open_nl_dbg$final_loud
    row <- score_row("A", nm, fl, g, build_target(hl_freqs, sp, htl6, rep(0, 6), g, EVAL_LVL),
                     cap = l0 + BUDGET,
                     sones_opt = if (is.null(ll)) NA_real_ else ll[["sones"]],
                     sones_model = loudness_of(EVAL_LVL, g, htl6, rep(0, 6))$total)
    save_row(row); progress(row)
  }
}

## Part B: Table 3 profiles at NAL-NL2 loudness (same setup as gen_iso_loudness_control_v2.R)
for (p in paste0("a", 1:5)) {
  td   <- jd2011_targets[[p]]
  htl  <- td$threshold
  loss <- rep(0, 6)
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", td$freq, EVAL_LVL)
  nal_gain_6  <- approx(log10(td$freq), nal_gain_19, log10(hl_freqs), rule = 2)$y
  nal_loud    <- loudness_of(EVAL_LVL, nal_gain_6, htl, loss)$total
  for (fl in c(0, -10)) {
    if (paste("B", p, fl) %in% key_done) next
    .open_nl_dbg$last_loud <- NULL
    g <- open_nl_single(speech = EVAL_LVL, threshold = htl, freq = hl_freqs,
                        loss = loss, cap_override = nal_loud, vent_floor = fl)$gain
    ll  <- .open_nl_dbg$final_loud
    row <- score_row("B", p, fl, g, build_target(hl_freqs, sp, htl, loss, g, EVAL_LVL),
                     cap = nal_loud,
                     sones_opt = if (is.null(ll)) NA_real_ else ll[["sones"]],
                     sones_model = loudness_of(EVAL_LVL, g, htl, loss)$total)
    save_row(row); progress(row)
  }
}

## ---- compare with anchor-on ----------------------------------------------

d <- read.csv(csv_path, stringsAsFactors = FALSE)
floor_eff <- function(x, prof, s_col) {
  a <- x[x$profile == prof & x$floor == 0, ]; z <- x[x$profile == prof & x$floor == -10, ]
  c(d_sones = z[[s_col[1]]] - a[[s_col[1]]],
    d_smooth = z$sii_smooth - a$sii_smooth,
    d_complete = z$sii_complete - a$sii_complete,
    d_ansi = z$sii_ansi - a$sii_ansi)
}

cat("\n\n==== Part A: audiogram family, 0.5-sone budget ====\n")
A <- d[d$part == "A", ]
offA <- do.call(rbind, lapply(unique(A$profile), function(nm)
  data.frame(audiogram = nm, edge = as.numeric(sub("^e(\\d+)_s\\d+$", "\\1", nm)),
             t(floor_eff(A, nm, "sones_opt")))))
offA$matched <- abs(offA$d_sones) <= 0.001

on <- read.csv(sweep_on, stringsAsFactors = FALSE)
if (!"d_smooth" %in% names(on)) {           # rescored sweep file: build pairs
  on <- on[on$budget == BUDGET, ]
  on <- do.call(rbind, lapply(unique(on$audiogram), function(nm) {
    a <- on[on$audiogram == nm & on$floor == 0, ]; z <- on[on$audiogram == nm & on$floor == -10, ]
    data.frame(audiogram = nm, edge = a$edge, d_sones = z$sones - a$sones,
               d_smooth = z$sii_smooth - a$sii_smooth,
               d_complete = z$sii_complete - a$sii_complete,
               d_ansi = z$sii_ansi - a$sii_ansi)
  }))
}
cmpA <- merge(on[, c("audiogram", "edge", "d_smooth", "d_complete", "d_ansi")],
              offA[, c("audiogram", "d_sones", "d_smooth", "d_complete", "d_ansi", "matched")],
              by = "audiogram", suffixes = c(".on", ".off"))
cat("\nMean floor effect by edge, anchor ON vs OFF (all pairs):\n")
print(round(aggregate(cbind(d_smooth.on, d_smooth.off, d_complete.on, d_complete.off,
                            d_ansi.on, d_ansi.off) ~ edge, data = cmpA, FUN = mean), 4))
cat(sprintf("\nanchor-off pairs matched in loudness: %d of 16\n", sum(offA$matched)))
cat("\nPer audiogram (smoothed floor effect, ON -> OFF):\n")
for (i in order(cmpA$edge, cmpA$audiogram))
  cat(sprintf("  %-10s  %+.4f -> %+.4f   (complete %+.4f -> %+.4f, ANSI %+.4f -> %+.4f)%s\n",
              cmpA$audiogram[i], cmpA$d_smooth.on[i], cmpA$d_smooth.off[i],
              cmpA$d_complete.on[i], cmpA$d_complete.off[i],
              cmpA$d_ansi.on[i], cmpA$d_ansi.off[i],
              if (cmpA$matched[i]) "" else "   [off-pair not matched]"))

cat("\n\n==== Part B: Table 3 profiles at NAL-NL2 loudness ====\n")
B  <- d[d$part == "B", ]
tb <- read.csv(table_on, stringsAsFactors = FALSE)
cat("  profile  smoothed ON -> OFF     complete ON -> OFF     ANSI ON -> OFF     d_sones(off)\n")
for (p in unique(B$profile)) {
  f <- floor_eff(B, p, "sones_model"); r <- tb[tb$Profile == p, ]
  cat(sprintf("  %-7s  %+.4f -> %+.4f     %+.4f -> %+.4f     %+.4f -> %+.4f     %+.4f\n",
              p, r$Floor_Effect_Smooth, f["d_smooth"], r$Floor_Effect_Desens, f["d_complete"],
              r$Floor_Effect_Raw, f["d_ansi"], f["d_sones"]))
}

cat(sprintf("\ncsv: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
options(open_nl_starts = 3); rm(open_nl_single)
sink()
