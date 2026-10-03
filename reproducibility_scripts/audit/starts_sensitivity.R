## starts_sensitivity.R -------------------------------------------------------
## Does the +/-0.02 band in d_SII shrink as the number of multi-starts rises?
##
##   shrinks toward zero  -> local optima; more starts fixes it, and the small
##                           positive effects at edge 2000/3000 may be real
##   holds at ~0.02       -> systematic, driven by the anchor penalty; 0.02 is
##                           the resolution limit and edge 2000/3000 are null
##
## A negative d_SII is impossible for a real feasibility comparison (the
## floor-0 feasible set is contained in the floor--10 set), so the negative
## cells below are pure artefact and are the cleanest probe. Two large positive
## cells are included as controls; they should stay large.
##
## Run from the repository root with nothing else running.
## 8 cells x 2 floors x 3 start counts = 48 optimizations, roughly 70-90 min.
##
## FIRST: revert helpers_jaaa.R so options(open_nl_maxit = 800) is not undone
## by the on.exit() Gemini added, then check getOption("open_nl_maxit") is 800.
##
## If it errors partway, run  sink()  once at the prompt.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

STARTS_SEQ <- c(3, 10, 20)
DESENS     <- 1.0
EVAL_LVL   <- 65

out_dir <- file.path("reproducibility_scripts", "output", "isoloudness")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
log_path <- file.path(out_dir, sprintf("starts_sensitivity_%s.log", Sys.Date()))
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("starts_sensitivity.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("open_nl_maxit in force: %s\n\n", getOption("open_nl_maxit", "unset")))

ns       <- asNamespace("SII")
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

FAMILY <- rbind(
  e1000_s20 = c(10, 10, 10, 30.00000,  50.00000,  70.00000),
  e1000_s30 = c(10, 10, 10, 40.00000,  70.00000, 100.00000),
  e1500_s20 = c(10, 10, 10, 18.30075,  38.30075,  58.30075),
  e2000_s20 = c(10, 10, 10, 10.00000,  30.00000,  50.00000),
  e3000_s20 = c(10, 10, 10, 10.00000,  18.30075,  38.30075),
  e3000_s50 = c(10, 10, 10, 10.00000,  30.75187,  80.75187))

## cell = audiogram + budget, with the starts-3 d_SII already measured.
CELLS <- list(
  list(nm = "e3000_s20", b = 0.5, d3 = -0.0028, role = "artefact"),
  list(nm = "e3000_s20", b = 2.0, d3 = -0.0104, role = "artefact"),
  list(nm = "e1000_s30", b = 2.0, d3 = -0.0113, role = "artefact"),
  list(nm = "e1500_s20", b = 1.0, d3 = -0.0047, role = "artefact"),
  list(nm = "e2000_s20", b = 2.0, d3 = -0.0059, role = "artefact"),
  list(nm = "e3000_s50", b = 1.0, d3 = -0.0041, role = "artefact"),
  list(nm = "e1000_s30", b = 0.5, d3 = +0.0823, role = "control"),
  list(nm = "e1000_s20", b = 0.5, d3 = +0.0547, role = "control"))

## ---- debug copy: double-run disabled, loudness logged --------------------

src <- readLines("R/open_nl.R")
ok <- grepl("if \\(vent_floor < 0\\)", src[381]) &&
      grepl("if \\(vent_floor < 0\\)", src[404]) &&
      grepl("loudness_sones > dynamic_cap", src[256]) &&
      grepl("^\\s*\\}\\s*$", src[259])
if (!ok) {
  cat("ANCHOR CHECK FAILED at 256/259/381/404:\n")
  for (i in c(256, 259, 381, 404)) cat(sprintf("%5d | %s\n", i, src[i]))
  sink(); stop("Aborting: re-anchor against the current R/open_nl.R.")
}
cat("anchor check passed\n")
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
cat("double-run disabled\n\n")

sp <- build_opennl_speech(hl_freqs, EVAL_LVL)

run_cell <- function(nm, b, fl, st) {
  htl6 <- FAMILY[nm, ]
  l0 <- loudness_of(EVAL_LVL, rep(0, 6), htl6, rep(0, 6))$total
  options(open_nl_starts = st)
  .open_nl_dbg$last_loud <- NULL
  g <- open_nl_single(speech = EVAL_LVL, threshold = htl6, freq = hl_freqs,
                      loss = rep(0, 6), cap_override = l0 + b,
                      vent_floor = fl, desensitization_scale = DESENS)$gain
  s <- report_sii(build_target(hl_freqs, sp, htl6, rep(0, 6), g, EVAL_LVL),
                  "johnson2011_smoothed", desensitization_scale = DESENS)
  ll <- .open_nl_dbg$final_loud
  list(sii = s, sones = if (is.null(ll)) NA_real_ else ll[["sones"]], gain = g)
}

rows <- list()
for (cl in CELLS) {
  cat(sprintf("\n-- %s, budget %.1f (%s, d_SII at 3 starts = %+.4f) --\n",
              cl$nm, cl$b, cl$role, cl$d3))
  for (st in STARTS_SEQ) {
    a <- run_cell(cl$nm, cl$b, 0,   st)
    z <- run_cell(cl$nm, cl$b, -10, st)
    d <- z$sii - a$sii
    rows[[length(rows) + 1]] <- data.frame(
      audiogram = cl$nm, budget = cl$b, role = cl$role, starts = st,
      sii0 = a$sii, sii10 = z$sii, d_sii = d,
      d_sones = z$sones - a$sones, stringsAsFactors = FALSE)
    cat(sprintf("   %2d starts: SII0 %.4f  SII-10 %.4f  d_SII %+.4f  d_sones %+.4f\n",
                st, a$sii, z$sii, d, z$sones - a$sones))
  }
}
df <- do.call(rbind, rows)

csv_path <- file.path(out_dir, sprintf("starts_sensitivity_%s.csv", Sys.Date()))
write.csv(df, csv_path, row.names = FALSE)

cat("\n\n==== Summary: d_SII by number of starts ====\n\n")
cat("  audiogram   budget  role        3 starts   10 starts   20 starts\n")
for (cl in CELLS) {
  v <- df[df$audiogram == cl$nm & df$budget == cl$b, ]
  v <- v[match(STARTS_SEQ, v$starts), ]
  cat(sprintf("  %-10s %6.1f  %-10s %+9.4f  %+10.4f  %+10.4f\n",
              cl$nm, cl$b, cl$role, v$d_sii[1], v$d_sii[2], v$d_sii[3]))
}

art <- df[df$role == "artefact", ]
cat("\nLargest artefact magnitude by start count (this is the noise floor):\n")
for (st in STARTS_SEQ) {
  cat(sprintf("  %2d starts: %.4f\n", st, max(abs(art$d_sii[art$starts == st]))))
}
cat("\nIf that shrinks toward zero the band is local optima; if it holds near\n")
cat("0.02 it is systematic and belongs in Methods as the resolution limit.\n")

cat(sprintf("\ncsv written to: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
options(open_nl_starts = 3); rm(open_nl_single)
sink()
