## diagnose_multistart.R -----------------------------------------------------
## Diagnostics for the multi-start selection anomaly in open_nl()
## (manuscript_todo.md, section 2).
##
## Run from the repository root, with nothing else running.
## Writes a log to reproducibility_scripts/output/diagnostics_multistart_<date>.log
## and also prints to the console.
##
## If the script errors partway through, run  sink()  once at the prompt to
## restore normal output before doing anything else.
## ---------------------------------------------------------------------------

## ---- 0. Setup -------------------------------------------------------------

devtools::load_all(quiet = TRUE)
source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

log_path <- file.path("reproducibility_scripts", "output",
                      sprintf("diagnostics_multistart_%s.log", Sys.Date()))
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
con <- file(log_path, open = "wt")
sink(con, split = TRUE)

cat("diagnose_multistart.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat("branch:   ", tryCatch(system("git rev-parse --abbrev-ref HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

f    <- c(250, 500, 1000, 2000, 4000, 8000)
sp   <- build_opennl_speech(f, 65)
htl5 <- jd2011_targets$a5$threshold
htl4 <- jd2011_targets$a4$threshold

## NOTE: this reproduces the roughness penalty as documented (0.001 * sum of
## squared adjacent-band differences). If the penalty is computed on octave-band
## gains that differ from the returned gain vector, Part A will show it and this
## helper needs adjusting before the numbers below mean anything.
rough <- function(g) sum(diff(g)^2) * 0.001

pinned <- function(g, floor, ceiling = 80) {
  lo <- which(abs(g - floor)   < 1e-6)
  hi <- which(abs(g - ceiling) < 1e-6)
  if (!length(lo) && !length(hi)) return("none")
  paste(c(if (length(lo)) paste0("floor@", paste(f[lo], collapse = ",")),
          if (length(hi)) paste0("ceil@",  paste(f[hi], collapse = ","))),
        collapse = " ")
}

run_one <- function(htl, cap, floor, n_starts, seed = 1) {
  options(open_nl_starts = n_starts)
  set.seed(seed)
  g <- open_nl(speech = 65, threshold = htl, freq = f, loss = rep(0, 6),
               cap_override = cap, vent_floor = floor)$gain
  s <- report_sii(build_target(f, sp, htl, rep(0, 6), g, eval_level = 65),
                  "johnson2011_smoothed")
  list(gain = g, sii = s, rough = rough(g), pinned = pinned(g, floor))
}

summarise <- function(rows, floor) {
  tab <- do.call(rbind, lapply(rows, function(r)
    data.frame(SII = round(r$sii, 4), roughness = round(r$rough, 4),
               pinned = r$pinned, stringsAsFactors = FALSE)))
  gains <- do.call(rbind, lapply(rows, function(r) round(r$gain, 2)))
  colnames(gains) <- paste0(f, "Hz")
  print(cbind(tab, gains))
}

## ---- Part A. What the objective and the loop actually operate on ----------
## Reads, does not run. The fix in section 2 assumes the objective can be
## evaluated on a gain vector. If the optimizer's parameters are not plain
## per-band gains, that assumption fails and the fix has to change shape first.

cat("\n==== PART A: source of the objective and multi-start loop ====\n\n")

src <- readLines("R/open_nl.R")
key <- grep("open_nl_starts|opt_res|optim\\(|Nelder|gain_oct|roughness",
            src, value = FALSE)
cat("Lines mentioning the loop, optimizer or roughness term:\n")
for (i in key) cat(sprintf("%5d | %s\n", i, src[i]))

cat("\n--- lines 270-340 verbatim ---\n")
rng <- seq(max(1, 270), min(length(src), 340))
for (i in rng) cat(sprintf("%5d | %s\n", i, src[i]))

## ---- Part B. Seed sensitivity (the precision estimate for Methods) --------
## Spread of SII across seeds at one fixed setting IS the uncertainty on every
## SII in the paper. Report SII and roughness separately; do not rank on their
## difference, which is only two terms of a nine-term objective.

cat("\n\n==== PART B: A5, 10 starts, seeds 1-5 ====\n\n")

b <- lapply(1:5, function(sd) run_one(htl5, cap = 5.50, floor = -10,
                                      n_starts = 10, seed = sd))
names(b) <- paste0("seed", 1:5)
summarise(b, floor = -10)

sii_vals <- vapply(b, function(r) r$sii, numeric(1))
cat(sprintf("\nSII across seeds: mean %.4f  sd %.4f  range %.4f\n",
            mean(sii_vals), sd(sii_vals), diff(range(sii_vals))))

## ---- Part C. Does the anomaly reproduce, and is anything pinned? ----------
## Reruns the 10-vs-20 pair from the checklist and reports the gains alongside
## SII and roughness, so a binding clamp shows up in the same table as the
## score it would explain.

cat("\n\n==== PART C: A5, cap 5.50, floor -10, starts 3/10/20/40 ====\n\n")

cc <- lapply(c(3, 10, 20, 40), function(n) run_one(htl5, 5.50, -10, n))
names(cc) <- paste0("starts", c(3, 10, 20, 40))
summarise(cc, floor = -10)

## ---- Part D. Is A4 affected, or only A5? ---------------------------------
## Decides whether a fix has to be applied everywhere or only to the profound
## case, and whether the vent floor is what triggers it.

cat("\n\n==== PART D: A4, cap 6.56, starts 1/3/10 ====\n")

for (fl in c(0, -10)) {
  cat(sprintf("\n-- floor %d --\n", fl))
  dd <- lapply(c(1, 3, 10), function(n) run_one(htl4, 6.56, fl, n))
  names(dd) <- paste0("starts", c(1, 3, 10))
  summarise(dd, floor = fl)
}

## ---- Done -----------------------------------------------------------------

options(open_nl_starts = 3)
cat("\n\nfinished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("log written to:", log_path, "\n")
sink()
