## rerun_complete_objective.R ---------------------------------------------------
## Reruns every optimization behind Tables 3-5 and Figure 2 with Open-NL's
## objective set to the complete Johnson & Dillon (2011) desensitized SII, the
## new default in R/open_nl.R (objective_sii = "johnson2011_desensitized").
##
## Steps, in order of importance (so an interrupted run still has the key parts):
##   1. Iso-loudness control, anchor on, A1-A7            14 optimizations
##   2. Iso-loudness control, anchor off, A1-A5            10
##   3. Audiogram family, 0.5-sone budget, anchor on       32
##   4. Loudness-unmatched pairs from step 3, 40 starts   up to 32 (usually ~12)
##   5. Audiogram family, 0.5-sone budget, anchor off      32
##   6. Audiogram family, 1/2/3-sone budgets, anchor on    96
## About 190-220 optimizations: roughly 10-11 hours at ~3 min each.
##
## Every solution is scored under the complete and ANSI SII. Results
## go to reproducibility_scripts/output/complete_objective/, leaving all earlier
## results in place. One CSV holds every solution; the script RESUMES from it,
## so an interrupt costs only the optimization in progress. Just source it again
## (if it stopped with an error, run  sink()  once at the prompt first).
##
## Run from the repo root, with nothing else running:
##   source("reproducibility_scripts/rerun_complete_objective.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")   # load_all(): picks up R/ changes
source("R/benchmark_targets.R")

STARTS    <- 20
STARTS_RR <- 40
EVAL_LVL  <- 65
BUDGETS   <- c(0.5, 1, 2, 3)
ISO_TOL   <- 0.001            # sones; same matching criterion as before
hl_freqs  <- c(250, 500, 1000, 2000, 4000, 8000)
gcols     <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")

out_dir  <- file.path("reproducibility_scripts", "output", "complete_objective")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(out_dir, "all_solutions.csv")
log_path <- file.path(out_dir, sprintf("rerun_complete_objective_%s.log", Sys.Date()))

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
edge_of <- function(id) as.numeric(sub("^e(\\d+)_s\\d+$", "\\1", id))
loss_of <- function(p) if (p == "a6") rep(30, 6) else if (p == "a7") rep(50, 6) else rep(0, 6)

## ---- preconditions -------------------------------------------------------------
obj_default <- eval(formals(open_nl)$objective_sii)[1]
if (!identical(obj_default, "johnson2011_desensitized"))
  stop("open_nl()'s objective_sii default is not johnson2011_desensitized; update R/open_nl.R first.")
s <- readLines("R/sii.R")
if (!any(grepl("^\\s*gain <- final_output - speech\\s*$", s)))
  stop("R/sii.R does not carry the negative-gain fix.")

## ---- instrumented copies of open_nl(): loudness logged, anchor on / off ---------
## Anchored by pattern, not line number. Logging only records values; it does not
## change the optimization.
src <- readLines("R/open_nl.R")
find1 <- function(pattern) {
  i <- grep(pattern, src, fixed = TRUE)
  if (length(i) != 1) stop(sprintf("expected one match in R/open_nl.R for: %s (found %d)", pattern, length(i)))
  i
}
i_cap <- find1("if (!is.null(cap_override)) dynamic_cap <- cap_override")
i_fin <- find1("clamped_shifts <- pmax(-60, pmin(30, best_shifts))")
i_anc <- find1("anchor_penalty <- sum(abs(shifts)) * 0.1")
i_obj <- find1("desensitization = objective_sii)")

instrument <- function(anchor_on) {
  s2 <- src
  if (!anchor_on) s2[i_anc] <- sub("* 0.1", "* 0", s2[i_anc], fixed = TRUE)
  ## insert the later line first so the earlier index stays valid
  s2 <- append(s2, c("      .open_nl_dbg$final_obj  <- obj_fn(best_shifts)",
                     "      .open_nl_dbg$final_loud <- .open_nl_dbg$last_loud"),
               after = i_fin - 1)
  s2 <- append(s2, "          .open_nl_dbg$last_loud <- c(sones = loudness_sones, cap = dynamic_cap)",
               after = i_cap)
  tmp <- tempfile(fileext = ".R"); writeLines(s2, tmp)
  e <- new.env(parent = asNamespace("SII")); sys.source(tmp, envir = e)
  f <- e$open_nl; environment(f) <- asNamespace("SII"); f
}
assign(".open_nl_dbg", new.env(parent = emptyenv()), envir = globalenv())
onl <- list(on = instrument(TRUE), off = instrument(FALSE))

## ---- one optimization, scored and saved -------------------------------------------
sp <- build_opennl_speech(hl_freqs, EVAL_LVL)
done <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors = FALSE) else NULL
key  <- function(set, anchor, profile, budget, floor, starts)
  paste(set, anchor, profile, ifelse(is.na(budget), "NA", as.character(budget)), floor, starts)
key_done <- if (is.null(done)) character(0) else
  key(done$set, done$anchor, done$profile, done$budget, done$floor, done$starts)
t_start <- Sys.time(); n_new <- 0

run_one <- function(set, anchor, profile, htl, loss, cap, budget, fl, starts) {
  k <- key(set, anchor, profile, budget, fl, starts)
  if (k %in% key_done) return(invisible(NULL))
  options(open_nl_starts = starts)
  .open_nl_dbg$last_loud <- NULL; .open_nl_dbg$final_loud <- NULL
  .open_nl_dbg$final_obj <- NA_real_
  g <- onl[[anchor]](speech = EVAL_LVL, threshold = htl, freq = hl_freqs, loss = loss,
                     cap_override = cap, vent_floor = fl)$gain
  tgt <- build_target(hl_freqs, sp, htl, loss, g, EVAL_LVL)
  ll  <- .open_nl_dbg$final_loud
  row <- data.frame(
    set = set, anchor = anchor, profile = profile, budget = budget, floor = fl,
    starts = starts, cap = cap,
    sones_opt   = if (is.null(ll)) NA_real_ else ll[["sones"]],
    sones_model = loudness_of(EVAL_LVL, g, htl, loss)$total,
    objective   = -.open_nl_dbg$final_obj,
    sii_complete = report_sii(tgt, "johnson2011_desensitized"),
    sii_ansi     = report_sii(tgt, "none"),
    g250 = g[1], g500 = g[2], g1000 = g[3], g2000 = g[4], g4000 = g[5], g8000 = g[6],
    stringsAsFactors = FALSE)
  write.table(row, csv_path, sep = ",", row.names = FALSE,
              col.names = !file.exists(csv_path), append = file.exists(csv_path))
  key_done <<- c(key_done, k)
  n_new <<- n_new + 1
  el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  cat(sprintf("  %-5s %-3s %-10s %-4s fl%+3d st%2d  sones %7.3f / cap %7.3f  complete SII %.4f  ANSI %.4f  [%d new, %.0fm]\n",
              set, anchor, profile, ifelse(is.na(budget), "iso", format(budget)), fl, starts,
              row$sones_opt, cap, row$sii_complete, row$sii_ansi, n_new, el))
  invisible(row)
}

## ---- run ----------------------------------------------------------------------------
con <- file(log_path, open = "at"); sink(con, split = TRUE)
cat("\nrerun_complete_objective.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("objective: %s (line %d) | starts %d (reruns %d) | open_nl_maxit %s\n",
            obj_default, i_obj, STARTS, STARTS_RR, getOption("open_nl_maxit", "unset")))
cat(sprintf("already done: %d solutions in %s\n\n", length(key_done), csv_path))

nal <- list()
for (p in paste0("a", 1:7)) {
  td <- jd2011_targets[[p]]
  g19 <- get_nalnl2_v2_target(p, "NAL-NL2", td$freq, EVAL_LVL)
  g6  <- approx(log10(td$freq), g19, log10(hl_freqs), rule = 2)$y
  nal[[p]] <- list(htl = td$threshold, loss = loss_of(p), gain = g6,
                   loud = loudness_of(EVAL_LVL, g6, td$threshold, loss_of(p))$total)
}
L0 <- sapply(rownames(FAMILY), function(nm)
  loudness_of(EVAL_LVL, rep(0, 6), FAMILY[nm, ], rep(0, 6))$total)

cat("==== Step 1-2: iso-loudness control ====\n")
for (anc in c("on", "off")) {
  profs <- if (anc == "on") paste0("a", 1:7) else paste0("a", 1:5)
  for (p in profs) for (fl in c(0, -10))
    run_one("iso", anc, p, nal[[p]]$htl, nal[[p]]$loss, nal[[p]]$loud, NA_real_, fl, STARTS)
}

cat("\n==== Step 3: audiogram family, 0.5 sone, anchor on ====\n")
for (nm in rownames(FAMILY)) for (fl in c(0, -10))
  run_one("sweep", "on", nm, FAMILY[nm, ], rep(0, 6), L0[[nm]] + 0.5, 0.5, fl, STARTS)

cat("\n==== Step 4: unmatched 0.5-sone pairs, 40 starts ====\n")
d <- read.csv(csv_path, stringsAsFactors = FALSE)
s3 <- d[d$set == "sweep" & d$anchor == "on" & d$budget == 0.5 & d$starts == STARTS, ]
is_unmatched <- sapply(rownames(FAMILY), function(nm) {
  a <- s3[s3$profile == nm & s3$floor == 0, ]; z <- s3[s3$profile == nm & s3$floor == -10, ]
  nrow(a) == 1 && nrow(z) == 1 && isTRUE(abs(z$sones_opt - a$sones_opt) > ISO_TOL)
})
unmatched <- rownames(FAMILY)[is_unmatched]
cat(sprintf("  %d unmatched: %s\n", length(unmatched), paste(unmatched, collapse = ", ")))
for (nm in unmatched) for (fl in c(0, -10))
  run_one("sweep", "on", nm, FAMILY[nm, ], rep(0, 6), L0[[nm]] + 0.5, 0.5, fl, STARTS_RR)

cat("\n==== Step 5: audiogram family, 0.5 sone, anchor off ====\n")
for (nm in rownames(FAMILY)) for (fl in c(0, -10))
  run_one("sweep", "off", nm, FAMILY[nm, ], rep(0, 6), L0[[nm]] + 0.5, 0.5, fl, STARTS)

cat("\n==== Step 6: audiogram family, 1/2/3 sones, anchor on ====\n")
for (b in c(1, 2, 3)) for (nm in rownames(FAMILY)) for (fl in c(0, -10))
  run_one("sweep", "on", nm, FAMILY[nm, ], rep(0, 6), L0[[nm]] + b, b, fl, STARTS)

cat(sprintf("\noptimizations finished at %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
options(open_nl_starts = 3)

## =====================================================================================
## Report
## =====================================================================================
d <- read.csv(csv_path, stringsAsFactors = FALSE)

## sweep: for each (anchor, audiogram, budget) keep the highest-starts pair
sw <- d[d$set == "sweep", ]
sw <- do.call(rbind, lapply(split(sw, list(sw$anchor, sw$profile, sw$budget), drop = TRUE),
                            function(x) x[x$starts == max(x$starts), ]))
pairs <- do.call(rbind, lapply(split(sw, list(sw$anchor, sw$profile, sw$budget), drop = TRUE),
  function(x) {
    a <- x[x$floor == 0, ]; z <- x[x$floor == -10, ]
    if (nrow(a) != 1 || nrow(z) != 1) return(NULL)
    data.frame(anchor = a$anchor, audiogram = a$profile, edge = edge_of(a$profile),
               budget = a$budget, starts = a$starts,
               d_sones = z$sones_opt - a$sones_opt, unspent_m10 = z$cap - z$sones_opt,
               d_complete = z$sii_complete - a$sii_complete,
               d_ansi = z$sii_ansi - a$sii_ansi,
               stringsAsFactors = FALSE)
  }))
pairs$matched <- !is.na(pairs$d_sones) & abs(pairs$d_sones) <= ISO_TOL
r4 <- function(x) round(x, 4)

cat("\n\n==== TABLE 3: mean floor effect at 0.5 sone, by audible edge (all pairs) ====\n")
t3 <- pairs[pairs$budget == 0.5, ]
w <- merge(aggregate(cbind(d_complete, d_ansi) ~ edge, t3[t3$anchor == "on", ], mean),
           aggregate(cbind(d_complete, d_ansi) ~ edge, t3[t3$anchor == "off", ], mean),
           by = "edge", suffixes = c(".on", ".off"))
print(r4(w[, c("edge", "d_complete.on", "d_complete.off", "d_ansi.on", "d_ansi.off")]),
      row.names = FALSE)
cat(sprintf("matched at 0.5 sone: anchor on %d of 16, anchor off %d of 16\n",
            sum(t3$matched[t3$anchor == "on"]), sum(t3$matched[t3$anchor == "off"])))

cat("\n==== Per audiogram, 0.5 sone (complete / ANSI floor effect; d_sones; unspent at -10) ====\n")
for (nm in rownames(FAMILY)) {
  on <- t3[t3$anchor == "on" & t3$audiogram == nm, ]; of <- t3[t3$anchor == "off" & t3$audiogram == nm, ]
  if (!nrow(on) || !nrow(of)) next
  cat(sprintf("  %-10s ON  %+.4f / %+.4f  d_sones %+.3f unspent %.3f st%d%s | OFF %+.4f / %+.4f  d_sones %+.3f unspent %.3f%s\n",
              nm, on$d_complete, on$d_ansi, on$d_sones, on$unspent_m10, on$starts,
              if (isTRUE(on$matched)) "" else " [NM]", of$d_complete, of$d_ansi, of$d_sones,
              of$unspent_m10, if (isTRUE(of$matched)) "" else " [NM]"))
}

cat("\n==== All budgets, anchor on: mean floor effect by edge (rows) x budget (cols) ====\n")
po <- pairs[pairs$anchor == "on", ]
for (met in c("d_complete", "d_ansi")) {
  cat(sprintf("\n  %s\n", met)); print(r4(tapply(po[[met]], list(po$edge, po$budget), mean)))
}
cat("\n  matched pairs by budget:\n"); print(tapply(po$matched, po$budget, sum))

cat("\n==== Resolution limit: negative complete-SII floor effects, matched anchor-on pairs ====\n")
m <- po[po$matched, ]
neg <- -m$d_complete[m$d_complete < 0]
cat(sprintf("  %d matched pairs, %d negative; median %.4f, max %.4f  <- resolution limit\n",
            nrow(m), length(neg), if (length(neg)) median(neg) else NA_real_,
            if (length(neg)) max(neg) else NA_real_))

cat("\n==== Monotonicity in budget (complete SII should not fall as budget rises) ====\n")
swo <- sw[sw$anchor == "on", ]
for (fl in c(0, -10)) for (nm in rownames(FAMILY)) {
  v <- swo[swo$profile == nm & swo$floor == fl, ]; v <- v[order(v$budget), ]
  if (nrow(v) > 1 && any(diff(v$sii_complete) < -1e-6))
    cat(sprintf("  %-10s fl%+3d  %s  <-- non-monotone\n", nm, fl,
                paste(sprintf("%.4f", v$sii_complete), collapse = "  ")))
}

iso <- d[d$set == "iso", ]
get_iso <- function(anc, p, fl, col) iso[iso$anchor == anc & iso$profile == p & iso$floor == fl, col]
nal_sii <- sapply(names(nal), function(p) {
  t <- build_target(hl_freqs, sp, nal[[p]]$htl, nal[[p]]$loss, nal[[p]]$gain, EVAL_LVL)
  c(complete = report_sii(t, "johnson2011_desensitized"), ansi = report_sii(t, "none"))
})

cat("\n\n==== TABLE 4: iso-loudness control, complete SII, anchor on ====\n")
cat("  prof  NAL sones  NAL SII  ONL 0 dB  ONL -10 dB  optimizer  floor    iso diff (sones)\n")
for (p in paste0("a", 1:7)) {
  c0 <- get_iso("on", p, 0, "sii_complete"); c10 <- get_iso("on", p, -10, "sii_complete")
  cat(sprintf("  %-4s  %7.2f   %.3f    %.3f     %.3f      %+.3f    %+.3f   %+.4f\n",
              p, nal[[p]]$loud, nal_sii["complete", p], c0, c10, c0 - nal_sii["complete", p],
              c10 - c0, get_iso("on", p, -10, "sones_model") - get_iso("on", p, 0, "sones_model")))
}
cat("\n  optimizer effect under ANSI, anchor on:\n")
for (p in paste0("a", 1:7))
  cat(sprintf("  %-4s  ANSI %+.3f\n", p,
              get_iso("on", p, 0, "sii_ansi") - nal_sii["ansi", p]))

cat("\n==== TABLE 5: iso-loudness floor effect ====\n")
cat("  prof  complete on  complete off  ANSI on   ANSI off   d_sones on / off\n")
for (p in paste0("a", 1:7)) {
  ff <- function(anc, col) if (anc == "off" && p %in% c("a6", "a7")) NA else
    get_iso(anc, p, -10, col) - get_iso(anc, p, 0, col)
  cat(sprintf("  %-4s  %+.3f       %+.3f        %+.3f    %+.3f     %+.4f / %+.4f\n",
              p, ff("on", "sii_complete"), ff("off", "sii_complete"), ff("on", "sii_ansi"),
              ff("off", "sii_ansi"), ff("on", "sones_model"), ff("off", "sones_model")))
}
cat("\n  negative-gain bands at -10 dB (anchor on):\n")
for (p in paste0("a", 1:7)) {
  g <- as.numeric(iso[iso$anchor == "on" & iso$profile == p & iso$floor == -10, gcols])
  cat(sprintf("  %-4s %s\n", p, if (any(g < -0.001)) paste(hl_freqs[g < -0.001], collapse = "/") else "none"))
}

## Consistency check: A1-A5 must reproduce complete_objective_check.R exactly
## (same objective, same seeds; only the logging differs).
chk_csv <- file.path("reproducibility_scripts", "output", "isoloudness", "complete_objective_starts20.csv")
if (file.exists(chk_csv)) {
  ck <- read.csv(chk_csv, stringsAsFactors = FALSE)
  dev <- sapply(seq_len(nrow(ck)), function(i) {
    r <- iso[iso$anchor == ck$anchor[i] & iso$profile == ck$profile[i] & iso$floor == ck$floor[i], ]
    if (!nrow(r)) NA else max(abs(as.numeric(r[, gcols]) - as.numeric(ck[i, gcols])))
  })
  cat(sprintf("\nconsistency with complete_objective_check.R: max gain difference %.2e dB over %d solutions\n",
              max(dev, na.rm = TRUE), sum(!is.na(dev))))
}

write.csv(pairs, file.path(out_dir, "sweep_pairs.csv"), row.names = FALSE)
cat(sprintf("\ncsv: %s\npairs: %s\n", csv_path, file.path(out_dir, "sweep_pairs.csv")))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Paste everything from '==== TABLE 3' down to Claude.\n")
sink(); close(con)
