## complete_objective_check.R --------------------------------------------------
## Would the floor effect under the published (complete) Johnson & Dillon
## correction be larger if the optimizer targeted that metric directly?
##
## Every reported solution was optimized on the smoothed desensitized SII
## (K' = K * m) and then scored on the complete SII (K' = (K^p + m^p)^(1/p)).
## For the thresholds used (0-110 dB HL) p lies between -15 and -1.25, so the
## complete correction behaves roughly as min(K, m) and gives little credit for
## audibility above m, while the smoothed one keeps crediting it. An optimizer
## aimed at the complete SII could therefore spend freed loudness differently.
##
## This script re-optimizes profiles A1-A5 at NAL-NL2's own loudness (the
## iso-loudness control), both floors, anchor penalty on and off, with the
## objective's SII switched to "johnson2011_desensitized" in an in-memory copy of
## R/open_nl.R. Nothing else changes. Scores every solution on all three SII
## versions and prints the complete-SII floor effect beside the reported one.
##
## Reading the result: the complete-SII floor effect of a solution optimized
## ON the complete SII is the right number to quote for that metric. If it
## stays at or below ~0.006 for A4 and A5, the manuscript's conclusion stands
## and can say so; if it grows, the conclusion must change.
##
## Run AFTER rerun_iso_after_sii_fix.R has finished (it needs the fixed
## sii.R and compares against that script's output).
## Runtime: 20 optimizations at 20 starts, roughly 70-80 minutes.
## Resumes from its CSV if interrupted. If it errors, run  sink()  once, then
## source it again.
##
## Run from the repo root:
##   source("reproducibility_scripts/complete_objective_check.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")

STARTS   <- 20
EVAL_LVL <- 65
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

out_dir  <- file.path("reproducibility_scripts", "output", "isoloudness")
csv_path <- file.path(out_dir, sprintf("complete_objective_starts%d.csv", STARTS))
log_path <- file.path(out_dir, sprintf("complete_objective_starts%d_%s.log", STARTS, Sys.Date()))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

s <- readLines("R/sii.R")
if (!any(grepl("^\\s*gain <- final_output - speech\\s*$", s)))
  stop("R/sii.R does not carry the negative-gain fix; run after that fix.")

con <- file(log_path, open = "at"); sink(con, split = TRUE)
cat("\ncomplete_objective_check.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("starts %d | open_nl_maxit %s\n\n", STARTS, getOption("open_nl_maxit", "unset")))

## ---- two in-memory variants of open_nl(): objective on the complete SII ----
ns  <- asNamespace("SII")
src <- readLines("R/open_nl.R")
i_obj <- grep('desensitization = "johnson2011_smoothed"', src, fixed = TRUE)
i_anc <- grep("anchor_penalty <- sum(abs(shifts)) * 0.1", src, fixed = TRUE)
if (length(i_obj) != 1 || length(i_anc) != 1) {
  sink(); stop("Could not find the objective's SII call or the anchor line in R/open_nl.R.")
}
src[i_obj] <- sub("johnson2011_smoothed", "johnson2011_desensitized", src[i_obj], fixed = TRUE)
build <- function(s) {
  tmp <- tempfile(fileext = ".R"); writeLines(s, tmp)
  e <- new.env(parent = ns); sys.source(tmp, envir = e)
  f <- e$open_nl; environment(f) <- ns; f
}
onl_complete_on  <- build(src)
src_off <- src; src_off[i_anc] <- sub("* 0.1", "* 0", src_off[i_anc], fixed = TRUE)
onl_complete_off <- build(src_off)
cat(sprintf("objective switched to complete SII (line %d); anchor-off variant patches line %d\n\n",
            i_obj, i_anc))

## ---- run ------------------------------------------------------------------
done <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors = FALSE) else NULL
key_done <- if (is.null(done)) character(0) else paste(done$profile, done$anchor, done$floor)
options(open_nl_starts = STARTS)
sp <- build_opennl_speech(hl_freqs, EVAL_LVL)
t_start <- Sys.time()

for (p in paste0("a", 1:5)) {
  td   <- jd2011_targets[[p]]
  htl  <- td$threshold
  loss <- rep(0, 6)
  nal_gain_19 <- get_nalnl2_v2_target(p, "NAL-NL2", td$freq, EVAL_LVL)
  nal_gain_6  <- approx(log10(td$freq), nal_gain_19, log10(hl_freqs), rule = 2)$y
  nal_loud    <- loudness_of(EVAL_LVL, nal_gain_6, htl, loss)$total
  for (anc in c("on", "off")) for (fl in c(0, -10)) {
    if (paste(p, anc, fl) %in% key_done) next
    f <- if (anc == "on") onl_complete_on else onl_complete_off
    g <- f(speech = EVAL_LVL, threshold = htl, freq = hl_freqs, loss = loss,
           cap_override = nal_loud, vent_floor = fl)$gain
    tgt <- build_target(hl_freqs, sp, htl, loss, g, EVAL_LVL)
    row <- data.frame(profile = p, anchor = anc, floor = fl, starts = STARTS,
                      cap = nal_loud, sones = loudness_of(EVAL_LVL, g, htl, loss)$total,
                      sii_complete = report_sii(tgt, "johnson2011_desensitized"),
                      sii_smooth   = report_sii(tgt, "johnson2011_smoothed"),
                      sii_ansi     = report_sii(tgt, "none"),
                      g250 = g[1], g500 = g[2], g1000 = g[3], g2000 = g[4], g4000 = g[5], g8000 = g[6],
                      stringsAsFactors = FALSE)
    write.table(row, csv_path, sep = ",", row.names = FALSE,
                col.names = !file.exists(csv_path), append = file.exists(csv_path))
    el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
    cat(sprintf("  %s anchor %-3s fl%+3d  sones %6.3f / cap %6.3f  complete SII %.4f  %.0fm\n",
                p, anc, fl, row$sones, row$cap, row$sii_complete, el))
  }
}

## ---- compare with the smoothed-objective solutions --------------------------
d <- read.csv(csv_path, stringsAsFactors = FALSE)
ff <- function(x, p, a, col) x[x$profile == p & x$anchor == a & x$floor == -10, col] -
                             x[x$profile == p & x$anchor == a & x$floor == 0, col]
on_tab <- read.csv("reproducibility_scripts/output/jaaa_audmod/table2_iso_loudness_v2.csv",
                   stringsAsFactors = FALSE)
off_tab <- read.csv(file.path(out_dir, "anchor_off_starts20.csv"), stringsAsFactors = FALSE)
off_tab <- off_tab[off_tab$part == "B", ]
ffo <- function(p, col) off_tab[off_tab$profile == p & off_tab$floor == -10, col] -
                        off_tab[off_tab$profile == p & off_tab$floor == 0, col]

cat("\n\n==== Floor effect under the COMPLETE SII ====\n")
cat("reported = optimized on smoothed, scored on complete (Table 5)\n")
cat("direct   = optimized AND scored on complete (this script)\n\n")
cat("  profile   anchor ON: reported -> direct     anchor OFF: reported -> direct     d_sones on/off\n")
for (p in paste0("a", 1:5)) {
  cat(sprintf("  %-7s   %+.4f -> %+.4f              %+.4f -> %+.4f                %+.4f / %+.4f\n", p,
              on_tab$Floor_Effect_Desens[on_tab$Profile == p], ff(d, p, "on", "sii_complete"),
              ffo(p, "sii_complete"), ff(d, p, "off", "sii_complete"),
              ff(d, p, "on", "sones"), ff(d, p, "off", "sones")))
}
cat("\nComplete-SII level reached (0 dB floor): smoothed-objective vs complete-objective, anchor on\n")
for (p in paste0("a", 1:5))
  cat(sprintf("  %-7s  %.4f -> %.4f\n", p, on_tab$ONL0_SII_Desens[on_tab$Profile == p],
              d$sii_complete[d$profile == p & d$anchor == "on" & d$floor == 0]))

cat(sprintf("\ncsv: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
options(open_nl_starts = 3)
sink()
