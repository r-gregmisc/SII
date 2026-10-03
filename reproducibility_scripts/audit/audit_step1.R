## audit_step1.R --------------------------------------------------------------
## Two jobs:
##   Part 1  discover the loudness-engine API (fast, read-only)
##   Part 2  instrument open_nl() to log per-start objective values and the
##           penalty decomposition at the selected solution
##
## Run from the repository root with nothing else running.
## Nothing in the package is modified: Part 2 works on an in-memory copy of
## R/open_nl.R. The installed open_nl() is untouched.
##
## If it errors partway, run  sink()  once at the prompt.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

log_path <- file.path("reproducibility_scripts", "output",
                      sprintf("audit_step1_%s.log", Sys.Date()))
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("audit_step1.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

PKG <- "SII"
ns  <- asNamespace(PKG)

## ============================ PART 1: API discovery =========================
## Read-only. Tells me what to call for the AUDMOD sanity checks.

cat("==== PART 1: loudness engine API ====\n\n")

pat <- "loud|audmod|sone|phon|excit|specific|bram|ucl|threshold_tone"

cat("-- exported names matching the loudness pattern --\n")
exp_hits <- grep(pat, getNamespaceExports(PKG), value = TRUE, ignore.case = TRUE)
print(sort(exp_hits))

cat("\n-- internal (unexported) names matching --\n")
all_hits <- grep(pat, ls(ns, all.names = TRUE), value = TRUE, ignore.case = TRUE)
print(sort(setdiff(all_hits, exp_hits)))

cat("\n-- signatures --\n")
for (nm in sort(all_hits)) {
  obj <- tryCatch(get(nm, envir = ns), error = function(e) NULL)
  if (is.function(obj)) {
    cat("\n", nm, ":\n", sep = "")
    print(args(obj))
  }
}

cat("\n-- compiled entry points registered by the package --\n")
print(tryCatch(getDLLRegisteredRoutines(PKG), error = function(e) conditionMessage(e)))

cat("\n-- Rcpp exports declared in src/ --\n")
for (fl in list.files("src", pattern = "\\.cpp$", full.names = TRUE)) {
  ln <- readLines(fl, warn = FALSE)
  ix <- grep("Rcpp::export", ln)
  if (length(ix)) {
    cat("\n", fl, ":\n", sep = "")
    for (i in ix) cat(sprintf("%5d | %s\n%5d | %s\n", i, ln[i], i + 1, ln[i + 1]))
  }
}

cat("\n-- helpers_jaaa.R functions --\n")
print(sort(names(Filter(is.function, mget(ls(globalenv()), envir = globalenv())))))

cat("\n-- normal_speech_loudness, if present --\n")
if (exists("normal_speech_loudness", envir = ns)) {
  print(args(get("normal_speech_loudness", envir = ns)))
  print(get("normal_speech_loudness", envir = ns))
}

## ====================== PART 2: instrumented open_nl ========================
## Builds a debug copy of open_nl() with three logging lines inserted. The copy
## is given the package namespace as its environment, so every function it calls
## is the installed one; only the logging differs.

cat("\n\n==== PART 2: instrumented open_nl() ====\n\n")

src <- readLines("R/open_nl.R")

## Verify the anchors before touching anything. If the file has moved on since
## the diagnostic run, abort rather than instrument the wrong lines.
ok <- grepl("current_score <- -opt_res\\$value", src[320]) &&
      grepl("^\\s*\\}\\s*$",                     src[325]) &&
      grepl("return\\(-score",                   src[284])
if (!ok) {
  cat("ANCHOR CHECK FAILED - lines 320/325/284 are not what was expected:\n")
  for (i in c(284, 320, 325)) cat(sprintf("%5d | %s\n", i, src[i]))
  sink(); stop("Aborting: re-read R/open_nl.R and re-anchor the inserts.")
}
cat("anchor check passed (lines 284, 320, 325)\n\n")

.open_nl_dbg <- new.env(parent = emptyenv())

term_names <- c("score", "anchor_penalty", "loudness_penalty",
                "out_of_bounds_penalty", "spl_penalty", "order_penalty",
                "cr_penalty", "roughness_penalty", "abg_penalty")

ins_terms <- paste0(
  '        .open_nl_dbg$last_terms <- unlist(mget(c(',
  paste0('"', term_names, '"', collapse = ","),
  '), envir = environment(), ifnotfound = list(NA_real_), inherits = TRUE))')

ins_start <- '        .open_nl_dbg$starts <- c(.open_nl_dbg$starts, current_score)'

ins_final <- paste(
  '      .open_nl_dbg$final_total <- obj_fn(best_shifts)',
  '      .open_nl_dbg$final_terms <- .open_nl_dbg$last_terms',
  '      .open_nl_dbg$best_score  <- best_score',
  sep = "\n")

## Insert from the bottom up so earlier line numbers stay valid.
src <- append(src, ins_final, after = 325)
src <- append(src, ins_start, after = 320)
src <- append(src, ins_terms, after = 283)

tmp <- tempfile(fileext = ".R"); writeLines(src, tmp)
e <- new.env(parent = ns); sys.source(tmp, envir = e)
open_nl_dbg <- e$open_nl
environment(open_nl_dbg) <- ns

f    <- c(250, 500, 1000, 2000, 4000, 8000)
sp   <- build_opennl_speech(f, 65)
htl5 <- jd2011_targets$a5$threshold
htl4 <- jd2011_targets$a4$threshold

probe <- function(label, htl, cap, floor, n_starts) {
  .open_nl_dbg$starts <- NULL
  options(open_nl_starts = n_starts)
  g <- open_nl_dbg(speech = 65, threshold = htl, freq = f, loss = rep(0, 6),
                   cap_override = cap, vent_floor = floor)$gain
  s <- report_sii(build_target(f, sp, htl, rep(0, 6), g, eval_level = 65),
                  "johnson2011_smoothed")

  v <- .open_nl_dbg$starts
  cat(sprintf("\n--- %s, %d starts ---\n", label, n_starts))
  cat("per-start objective (higher is better):\n")
  cat(sprintf("  %s\n", paste(sprintf("%.4f", v), collapse = "  ")))
  cat(sprintf("  running best: %s\n", paste(sprintf("%.4f", cummax(v)), collapse = "  ")))
  cat(sprintf("  monotone in starts: %s | selected internal best: %.4f\n",
              !is.unsorted(cummax(v)), .open_nl_dbg$best_score))
  cat(sprintf("  zero-shift incumbent won: %s\n", max(v) <= .open_nl_dbg$best_score - 1e-9))

  tt <- .open_nl_dbg$final_terms
  cat("penalty decomposition at the selected solution:\n")
  print(round(tt, 4))
  cat(sprintf("  total objective %.4f (= -score + penalties)\n", .open_nl_dbg$final_total))
  cat(sprintf("  reported SII %.4f | active penalties: %s\n", s,
              paste(names(tt)[-1][which(tt[-1] > 1e-6)], collapse = ", ")))
  invisible(NULL)
}

cat("\n### A5, cap 5.50, floor -10 (the anomaly case)\n")
for (n in c(3, 10, 20)) probe("A5 floor -10", htl5, 5.50, -10, n)

cat("\n\n### A4, cap 6.56, floor 0 (clamp binds here)\n")
for (n in c(1, 3, 10)) probe("A4 floor 0", htl4, 6.56, 0, n)

cat("\n\n### A4, cap 6.56, floor -10\n")
for (n in c(1, 3, 10)) probe("A4 floor -10", htl4, 6.56, -10, n)

options(open_nl_starts = 3)
rm(open_nl_dbg)
cat("\n\nfinished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("log written to:", log_path, "\n")
sink()
