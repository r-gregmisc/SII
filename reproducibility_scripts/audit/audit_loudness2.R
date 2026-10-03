## audit_loudness2.R ----------------------------------------------------------
## Follow-up to audit_loudness.R:
##   D  is B1's 0.3161 result my tone construction or the engine?
##   E  what the Johnson & Dillon profiles actually are (context for B4)
##   F  does the loudness cap bind at the BUDGET caps used in the family sweep?
##
## Run from the repository root with nothing else running.
## D and E are instant. F runs optimizations - see FAMILY_SUBSET below to
## control how long it takes (default ~32 runs, roughly 25-30 minutes).
##
## If it errors partway, run  sink()  once at the prompt.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

log_path <- file.path("reproducibility_scripts", "output",
                      sprintf("audit_loudness2_%s.log", Sys.Date()))
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("audit_loudness2.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

ns       <- asNamespace("SII")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)

loud_full <- function(freq, level, htl6) {
  SII:::calculate_loudness_audmod(
    freq = freq, level_dB_per_Hz = level,
    audiogram_freq = hl_freqs, audiogram_HL = htl6,
    fs = 32000, N = 8192)
}
loud <- function(freq, level, htl6) loud_full(freq, level, htl6)$total

## ============== PART D: is level_dB_per_Hz a density or a level? ============
## A 40 dB SPL tone spread over 1, 2, 5 and 10 adjacent 10-Hz bins, each with
## the same TOTAL power. If the engine integrates a density correctly, all four
## give the same sones. If they scale with the number of bins, the argument is
## a per-bin level and my B1 tone was built wrong.

cat("==== PART D: tone construction ====\n\n")

dense_f <- seq(20, 15000, by = 10)

tone_nbins <- function(f0, spl_total, nbins, floor_dB = -200) {
  lev <- rep(floor_dB, length(dense_f))
  i0 <- which.min(abs(dense_f - f0))
  idx <- i0 + seq_len(nbins) - ceiling(nbins / 2)
  idx <- idx[idx >= 1 & idx <= length(dense_f)]
  ## total power split evenly, expressed as a per-Hz density over 10-Hz bins
  lev[idx] <- spl_total - 10 * log10(length(idx)) - 10 * log10(10)
  lev
}

cat("-- D1. 40 dB SPL at 1 kHz, same total power, spread over n bins --\n")
for (nb in c(1, 2, 5, 10)) {
  v <- loud(dense_f, tone_nbins(1000, 40, nb), rep(0, 6))
  cat(sprintf("  %2d bin(s): %.4f sones\n", nb, v))
}

cat("\n-- D2. Same, but treating the argument as a per-bin LEVEL (no /Hz term) --\n")
tone_level <- function(f0, spl_total, nbins, floor_dB = -200) {
  lev <- rep(floor_dB, length(dense_f))
  i0 <- which.min(abs(dense_f - f0))
  idx <- i0 + seq_len(nbins) - ceiling(nbins / 2)
  idx <- idx[idx >= 1 & idx <= length(dense_f)]
  lev[idx] <- spl_total - 10 * log10(length(idx))
  lev
}
for (nb in c(1, 2, 5, 10)) {
  v <- loud(dense_f, tone_level(1000, 40, nb), rep(0, 6))
  cat(sprintf("  %2d bin(s): %.4f sones\n", nb, v))
}

cat("\n-- D3. Full return structure (is $total the right field?) --\n")
str(loud_full(dense_f, tone_nbins(1000, 40, 1), rep(0, 6)))

cat("\n-- D4. Sanity anchor from the other direction --\n")
cat("   Unaided speech at 65 dB SPL, normal hearing, should be ~9.03:\n")
sp65 <- build_dense_spectrum(65, rep(0, 6), rep(0, 6))
cat(sprintf("   %.4f sones\n", loud(sp65$freq, sp65$level, rep(0, 6))))

## ================= PART E: what are the JD2011 profiles? ====================

cat("\n\n==== PART E: Johnson & Dillon profiles ====\n\n")
tt <- t(sapply(jd2011_targets, function(x) x$threshold))
colnames(tt) <- paste0(hl_freqs, "Hz")
print(round(tt, 1))

cat("\nUnaided loudness of 65 dB speech (L0) per profile:\n")
for (p in rownames(tt)) {
  l0 <- loudness_of(65, rep(0, 6), tt[p, ], rep(0, 6))$total
  cat(sprintf("  %-4s L0 = %7.4f sones\n", p, l0))
}

## ============ PART F: cap binding at the BUDGET caps, family sweep ==========
## audit_loudness.R used the default cap (9.033, normal-hearing loudness, the
## same for every listener). The family sweep instead caps at L0 + 0.5/1/2/3,
## which is far lower. This is the configuration the main results come from.

cat("\n\n==== PART F: cap binding at L0 + budget ====\n\n")

## Audiograms transcribed verbatim from gen_audiogram_family.log.
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

## Widen this to all 16 rows if you have the time; 4 rows x 4 budgets x 2 floors
## is about 32 optimizations.
FAMILY_SUBSET <- c("e1000_s30", "e1000_s40", "e2000_s40", "e3000_s40")
BUDGETS <- c(0.5, 1, 2, 3)

src <- readLines("R/open_nl.R")
ok <- grepl("loudness_sones > dynamic_cap", src[256]) &&
      grepl("^\\s*\\}\\s*$", src[259]) &&
      grepl("current_score <- -opt_res\\$value", src[320]) &&
      grepl("^\\s*\\}\\s*$", src[325])
if (!ok) {
  cat("ANCHOR CHECK FAILED at lines 256/259/320/325:\n")
  for (i in c(256, 259, 320, 325)) cat(sprintf("%5d | %s\n", i, src[i]))
  sink(); stop("Aborting: re-anchor the inserts.")
}
cat("anchor check passed\n\n")

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
sp <- build_opennl_speech(hl_freqs, 65)

cat("NOTE: L0 is taken as unaided loudness of 65 dB speech for that listener.\n")
cat("      Confirm this matches how the family script defines it.\n\n")
cat("  audiogram   budget  floor      cap    sones  headroom  binding     SII\n")

for (nm in FAMILY_SUBSET) {
  htl6 <- FAMILY[nm, ]
  l0 <- loudness_of(65, rep(0, 6), htl6, rep(0, 6))$total
  for (b in BUDGETS) {
    for (fl in c(0, -10)) {
      .open_nl_dbg$last_loud <- NULL
      g <- open_nl_dbg(speech = 65, threshold = htl6, freq = hl_freqs,
                       loss = rep(0, 6), cap_override = l0 + b,
                       vent_floor = fl)$gain
      s <- report_sii(build_target(hl_freqs, sp, htl6, rep(0, 6), g, 65),
                      "johnson2011_smoothed")
      ll <- .open_nl_dbg$final_loud
      if (is.null(ll)) {
        cat(sprintf("  %-10s %6.1f %6d   (loudness block not reached)\n", nm, b, fl))
        next
      }
      hr <- ll[["cap"]] - ll[["sones"]]
      cat(sprintf("  %-10s %6.1f %6d  %7.3f  %7.3f  %+8.4f  %-7s %7.4f\n",
                  nm, b, fl, ll[["cap"]], ll[["sones"]], hr,
                  if (abs(hr) < 0.01) "AT CAP" else if (hr < 0) "OVER" else "slack", s))
    }
  }
}

options(open_nl_starts = 3)
rm(open_nl_dbg)
cat("\n\nfinished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("log written to:", log_path, "\n")
sink()
