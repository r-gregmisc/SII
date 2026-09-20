## audit_cap_basis.R ---------------------------------------------------------
## Two questions about the loudness cap:
##
##   A  The manuscript states normal-hearing loudness of speech as 1.21, 6.81
##      and 20.52 sones at 50, 65 and 80 dB SPL. The AUDMOD path returns
##      3.1577, 9.0333 and 22.3887. Which is which, and where does the
##      manuscript's set come from? Leading hypothesis: the superseded
##      bramslow2004 engine (calculate_loudness_cpp), still exported.
##
##   B  What loudness does NAL-NL2 actually target for A1-A5? If an
##      established clinical rationale lands consistently somewhere, that is a
##      better justification for L_cap than a normative ceiling chosen by
##      construction.
##
## No optimizer, no options() changes, writes only its own log - safe to run
## beside a long optimization job.
## Run from the repository root.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

log_path <- file.path("reproducibility_scripts", "output",
                      sprintf("audit_cap_basis_%s.log", Sys.Date()))
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("audit_cap_basis.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
MANU <- c(`50` = 1.21, `65` = 6.81, `80` = 20.52)   # as printed in the manuscript

## ---- Part 0: signatures --------------------------------------------------

cat("==== PART 0: signatures ====\n\n")
for (nm in c("calculate_loudness", "calculate_loudness_cpp",
             "calculate_binaural_loudness", "normal_speech_loudness")) {
  obj <- tryCatch(get(nm, envir = asNamespace("SII")), error = function(e) NULL)
  if (is.function(obj)) { cat("\n", nm, ":\n", sep = ""); print(args(obj)) }
}
cat("\nget_nalnl2_v2_target (from helpers_jaaa.R):\n")
if (exists("get_nalnl2_v2_target")) print(args(get_nalnl2_v2_target)) else
  cat("  not found in the global environment\n")
cat("\nbenchmark_targets.R objects:\n")
print(ls(pattern = "target|nalnl2|jd2011"))

## ---- Part A: which engine produces the manuscript's numbers? -------------

cat("\n\n==== PART A: normal-hearing speech loudness by engine ====\n\n")

audmod_at <- function(level) {
  sp <- build_dense_spectrum(level, rep(0, 6), rep(0, 6))
  SII:::calculate_loudness_audmod(
    freq = sp$freq, level_dB_per_Hz = sp$level,
    audiogram_freq = hl_freqs, audiogram_HL = rep(0, 6),
    fs = 32000, N = 8192)$total
}

## The superseded engine takes band levels directly (inputF / inputLdB).
old_at <- function(level, dense = FALSE) {
  if (dense) {
    sp <- build_dense_spectrum(level, rep(0, 6), rep(0, 6))
    f <- sp$freq; l <- sp$level
  } else {
    f <- hl_freqs; l <- ltass_65 + (level - 65)
  }
  r <- SII:::calculate_loudness_cpp(inputF = f, inputLdB = l,
                                    HLcf = hl_freqs, HLdB = rep(0, 6))
  if (is.list(r)) {
    for (fld in c("Ldn", "total", "N_total", "loudness")) if (!is.null(r[[fld]])) return(r[[fld]])
    return(NA_real_)
  }
  as.numeric(r)
}

cat("  level   manuscript   AUDMOD (new)   bramslow2004 band   bramslow2004 dense\n")
for (lev in c(50, 65, 80)) {
  a <- tryCatch(audmod_at(lev),       error = function(e) NA_real_)
  b <- tryCatch(old_at(lev, FALSE),   error = function(e) NA_real_)
  d <- tryCatch(old_at(lev, TRUE),    error = function(e) NA_real_)
  cat(sprintf("  %3d %12.4f %14.4f %19.4f %20.4f\n",
              lev, MANU[as.character(lev)], a, b, d))
}
cat("\n  (structure of the superseded engine's return, for reference:)\n")
print(tryCatch(str(SII:::calculate_loudness_cpp(inputF = hl_freqs, inputLdB = ltass_65,
                                                HLcf = hl_freqs, HLdB = rep(0, 6))),
               error = function(e) conditionMessage(e)))

## ---- Part B: monaural vs binaural ---------------------------------------

cat("\n\n==== PART B: binaural summation ====\n\n")
m65 <- audmod_at(65)
bn <- tryCatch(SII:::calculate_binaural_loudness(m65, m65),
               error = function(e) conditionMessage(e))
cat(sprintf("  monaural (AUDMOD, 65 dB):        %.4f sones\n", m65))
cat(sprintf("  via calculate_binaural_loudness: %s\n", format(bn)))
cat(sprintf("  implied summation factor:        %s\n",
            if (is.numeric(bn)) sprintf("%.3f", bn / m65) else "n/a"))
cat(sprintf("  for reference, 2^0.75 =          %.3f\n", 2^0.75))

## ---- Part C: what does NAL-NL2 target? ----------------------------------

cat("\n\n==== PART C: unaided and NAL-NL2-aided loudness, A1-A7 ====\n\n")

cap65 <- SII:::normal_speech_loudness(65)
cat(sprintf("  package default cap at 65 dB: %.4f sones\n", cap65))
cat(sprintf("  manuscript L_cap at 65 dB:    %.2f sones\n\n", 7.00))
cat("  profile      L0    NAL-NL2 aided   aided/cap(pkg)   aided/7.00\n")

for (p in names(jd2011_targets)) {
  htl <- jd2011_targets[[p]]$threshold
  l0 <- tryCatch(loudness_of(65, rep(0, 6), htl, rep(0, 6))$total,
                 error = function(e) NA_real_)
  g <- tryCatch(get_nalnl2_v2_target(htl), error = function(e) NULL)
  if (is.null(g)) g <- tryCatch(jd2011_targets[[p]]$nalnl2, error = function(e) NULL)
  aided <- if (is.null(g)) NA_real_ else
    tryCatch(loudness_of(65, as.numeric(g)[1:6], htl, rep(0, 6))$total,
             error = function(e) NA_real_)
  cat(sprintf("  %-7s %7.4f %14s %16s %12s\n", p, l0,
              if (is.na(aided)) "unavailable" else sprintf("%.4f", aided),
              if (is.na(aided)) "-" else sprintf("%.3f", aided / cap65),
              if (is.na(aided)) "-" else sprintf("%.3f", aided / 7.00)))
}

cat("\n  If NAL-NL2 clusters at some fraction of the cap across profiles, that\n")
cat("  is an empirical anchor for L_cap. If it scatters, the cap is a modelling\n")
cat("  choice and the feasibility sweep is the right way to present it.\n")

cat("\n\nfinished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("log written to:", log_path, "\n")
sink()
