## audit_loudness.R -----------------------------------------------------------
## Loudness-engine validation, in three parts:
##   A  reconcile the three spectrum pipelines that feed AUDMOD
##   B  reference-free AUDMOD sanity checks (absolute behaviour)
##   C  is the loudness cap ever binding?
##
## Run from the repository root with nothing else running.
## Parts A and B are fast (a minute or two). Part C runs optimizations.
## Nothing in the package is modified; Part C uses an in-memory copy.
##
## If it errors partway, run  sink()  once at the prompt.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

log_path <- file.path("reproducibility_scripts", "output",
                      sprintf("audit_loudness_%s.log", Sys.Date()))
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("audit_loudness.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

ns       <- asNamespace("SII")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
amt_freqs <- c(125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000, 10000, 12500)

loud <- function(freq, level, htl6, ref = NULL) {
  SII:::calculate_loudness_audmod(
    freq = freq, level_dB_per_Hz = level,
    audiogram_freq = hl_freqs, audiogram_HL = htl6,
    fs = 32000, N = 8192, ref = ref)$total
}

## Rebuild the dense spectrum exactly as obj_fn does (open_nl.R lines 200-215),
## including the renormalisation step, so the two paths can be compared.
objfn_spectrum <- function(aided_spl, renormalise = TRUE,
                           dense_f = seq(20, 15000, by = 10)) {
  f_half <- seq(0, 15000, by = 0.5); f_half[1] <- 1
  li <- approx(log10(hl_freqs), aided_spl, log10(f_half), rule = 2)$y
  lo <- f_half < hl_freqs[1]; hi <- f_half > hl_freqs[6]
  li[lo] <- aided_spl[1] - 24 * log2(hl_freqs[1] / pmax(f_half[lo], 1))
  li[hi] <- aided_spl[6] - 24 * log2(f_half[hi] / hl_freqs[6])
  overall <- 10 * log10(sum(10^(li / 10)) * 0.5)

  dl <- approx(log10(hl_freqs), aided_spl, log10(dense_f), rule = 2)$y
  lo <- dense_f < hl_freqs[1]; hi <- dense_f > hl_freqs[6]
  dl[lo] <- aided_spl[1] - 24 * log2(hl_freqs[1] / dense_f[lo])
  dl[hi] <- aided_spl[6] - 24 * log2(dense_f[hi] / hl_freqs[6])
  if (renormalise) {
    current <- 10 * log10(sum(10^(dl / 10) * 10))
    dl <- dl + (overall - current)
  }
  list(freq = dense_f, level = dl, overall = overall)
}

## ===================== PART A: pipeline reconciliation ======================

cat("==== PART A: do the three spectrum pipelines agree? ====\n\n")

cat("-- A1. The cap itself: normal_speech_loudness() vs the helpers path --\n")
cat("   Both are meant to be normal-hearing loudness of unaided speech.\n\n")
for (lev in c(50, 65, 80)) {
  cap  <- SII:::normal_speech_loudness(lev)
  help <- loudness_of(lev, gain6 = rep(0, 6), threshold6 = rep(0, 6),
                      abg6 = rep(0, 6))$total
  cat(sprintf("  %2d dB SPL: normal_speech_loudness %8.4f | loudness_of %8.4f | diff %+8.4f (%+6.2f%%)\n",
              lev, cap, help, help - cap, 100 * (help - cap) / cap))
}

cat("\n-- A2. Same spectrum, four grid/renormalisation variants --\n")
cat("   Unaided normal-hearing speech at 65 dB SPL, so all four should agree.\n\n")
aided <- ltass_65
variants <- list(
  "helpers  10-23990, raw"       = list(s = list(freq = seq(10, 23990, by = 10)), renorm = NA),
  "obj_fn   20-15000, renorm"    = objfn_spectrum(aided, TRUE,  seq(20, 15000, by = 10)),
  "obj_fn   20-15000, raw"       = objfn_spectrum(aided, FALSE, seq(20, 15000, by = 10)),
  "obj_fn   10-23990, renorm"    = objfn_spectrum(aided, TRUE,  seq(10, 23990, by = 10))
)
hs <- build_dense_spectrum(65, rep(0, 6), rep(0, 6))
variants[[1]] <- list(freq = hs$freq, level = hs$level)

for (nm in names(variants)) {
  v <- variants[[nm]]
  val <- loud(v$freq, v$level, rep(0, 6))
  cat(sprintf("  %-28s %8.4f sones\n", nm, val))
}

cat("\n-- A3. Does passing a precomputed ref change the answer? --\n")
cat("   obj_fn passes ref built from a 13-point audiogram; helpers passes none.\n\n")
for (prof in c("a1", "a4", "a5")) {
  htl6 <- jd2011_targets[[prof]]$threshold
  htl13 <- approx(log10(hl_freqs), htl6, log10(amt_freqs), rule = 2)$y
  rf <- SII:::audmod_reference_cpp(fs = 32000, N = 8192,
                                   AGLoss_HL = htl13, AG_UCL_HL = rep(120, 13))
  sp <- objfn_spectrum(ltass_65 + 20)
  a <- loud(sp$freq, sp$level, htl6, ref = NULL)
  b <- loud(sp$freq, sp$level, htl6, ref = rf)
  cat(sprintf("  %-3s ref=NULL %8.4f | ref=precomputed %8.4f | diff %+8.4f\n",
              prof, a, b, b - a))
}

## ======================= PART B: AUDMOD sanity checks =======================
## Reference-free. Agreement with AMT to 6e-15 cannot detect an absolute-scale
## error that both implementations share; these can.

cat("\n\n==== PART B: AUDMOD absolute-behaviour checks ====\n\n")

## A tone of `spl` dB SPL placed in one 10-Hz bin: as a per-Hz density that is
## spl - 10*log10(binwidth).
tone_spectrum <- function(f0, spl, dense_f = seq(20, 15000, by = 10), floor_dB = -200) {
  lev <- rep(floor_dB, length(dense_f))
  i <- which.min(abs(dense_f - f0))
  lev[i] <- spl - 10 * log10(10)
  list(freq = dense_f, level = lev)
}

cat("-- B1. 1 kHz tone at 40 dB SPL should be 1 sone (normal hearing) --\n")
t40 <- tone_spectrum(1000, 40)
v40 <- loud(t40$freq, t40$level, rep(0, 6))
cat(sprintf("  got %.4f sones (target 1.0, ratio %.3f)\n\n", v40, v40 / 1))

cat("-- B2. Loudness should roughly double per 10 dB above 40 phons --\n")
levs <- seq(0, 100, by = 10)
vals <- vapply(levs, function(L) {
  ts <- tone_spectrum(1000, L); loud(ts$freq, ts$level, rep(0, 6))
}, numeric(1))
for (i in seq_along(levs)) {
  r <- if (i > 1 && vals[i - 1] > 1e-9) vals[i] / vals[i - 1] else NA_real_
  cat(sprintf("  %3d dB SPL: %10.4f sones   ratio to previous %s\n",
              levs[i], vals[i], ifelse(is.na(r), "--", sprintf("%.3f", r))))
}

cat("\n-- B3. Below threshold should be zero --\n")
for (lev in c(-20, -10, 0, 5)) {
  ts <- tone_spectrum(1000, lev)
  cat(sprintf("  normal hearing, 1 kHz at %+3d dB SPL: %.6f sones\n",
              lev, loud(ts$freq, ts$level, rep(0, 6))))
}
htl5 <- jd2011_targets$a5$threshold
for (lev in c(20, 40, 60)) {
  ts <- tone_spectrum(4000, lev)
  cat(sprintf("  A5 (4 kHz HTL %.0f dB), 4 kHz at %3d dB SPL: %.6f sones\n",
              htl5[5], lev, loud(ts$freq, ts$level, htl5)))
}

cat("\n-- B4. Recruitment: growth should be steeper with loss --\n")
profs <- intersect(c("a1", "a2", "a3", "a4", "a5"), names(jd2011_targets))
rec_levs <- seq(40, 100, by = 10)
cat(sprintf("  %-8s %s\n", "profile", paste(sprintf("%9d", rec_levs), collapse = "")))
for (prof in c("normal", profs)) {
  htl6 <- if (prof == "normal") rep(0, 6) else jd2011_targets[[prof]]$threshold
  vv <- vapply(rec_levs, function(L) {
    ts <- tone_spectrum(4000, L); loud(ts$freq, ts$level, htl6)
  }, numeric(1))
  cat(sprintf("  %-8s %s\n", prof, paste(sprintf("%9.3f", vv), collapse = "")))
}

## ===================== PART C: is the loudness cap binding? =================

cat("\n\n==== PART C: loudness at the selected solution vs the cap ====\n\n")

src <- readLines("R/open_nl.R")
ok <- grepl("loudness_sones > dynamic_cap", src[256]) &&
      grepl("^\\s*\\}\\s*$",                 src[259]) &&
      grepl("current_score <- -opt_res\\$value", src[320]) &&
      grepl("^\\s*\\}\\s*$",                 src[325])
if (!ok) {
  cat("ANCHOR CHECK FAILED at lines 256/259/320/325:\n")
  for (i in c(256, 259, 320, 325)) cat(sprintf("%5d | %s\n", i, src[i]))
  sink(); stop("Aborting: re-anchor the inserts against the current file.")
}
cat("anchor check passed (lines 256, 259, 320, 325)\n")

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
open_nl_dbg <- e$open_nl; environment(open_nl_dbg) <- ns

options(open_nl_starts = 3)
cat("\n  profile  floor   cap    sones   headroom   binding?\n")
for (prof in profs) {
  htl6 <- jd2011_targets[[prof]]$threshold
  for (fl in c(0, -10)) {
    .open_nl_dbg$last_loud <- NULL
    invisible(open_nl_dbg(speech = 65, threshold = htl6, freq = hl_freqs,
                          loss = rep(0, 6), vent_floor = fl))
    ll <- .open_nl_dbg$final_loud
    if (is.null(ll)) { cat(sprintf("  %-7s %5d   (loudness block not reached)\n", prof, fl)); next }
    hr <- ll[["cap"]] - ll[["sones"]]
    cat(sprintf("  %-7s %5d  %6.3f  %7.3f  %+9.4f   %s\n", prof, fl,
                ll[["cap"]], ll[["sones"]], hr,
                if (abs(hr) < 0.01) "AT CAP" else if (hr < 0) "OVER" else "slack"))
  }
}

options(open_nl_starts = 3)
rm(open_nl_dbg)
cat("\n\nfinished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("log written to:", log_path, "\n")
sink()
