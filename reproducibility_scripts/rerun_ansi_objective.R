## rerun_ansi_objective.R -------------------------------------------------------
## The clinical scenario: a fitting tuned to maximize the ANSI SII that real-ear
## measurement systems display. Same design as rerun_complete_objective.R, but the
## optimizer maximizes the ANSI SII (objective_sii = "none"). Each solution is
## scored under the ANSI and complete SII, so the report shows how much occlusion
## appears to help on the display and how much of that survives the published
## desensitization correction, and what chasing the display costs in complete SII
## relative to the complete-SII-optimal fitting from rerun_complete_objective.R.
##
## Steps:
##   1. Iso-loudness control, anchor on, A1-A7            14 optimizations
##   2. Iso-loudness control, anchor off, A1-A5            10
##   3. Audiogram family, 0.5-sone budget, anchor on       32
##   4. Loudness-unmatched pairs from step 3, 40 starts   up to 32 (usually few)
##   5. Audiogram family, 0.5-sone budget, anchor off      32
## About 90-100 optimizations: roughly 4-5 hours at ~3 min each.
##
## Results go to reproducibility_scripts/output/ansi_objective/. One CSV holds every
## solution; the script RESUMES from it, so just source it again after an interrupt
## (if it stopped with an error, run  sink()  once at the prompt first).
## Needs reproducibility_scripts/output/complete_objective/all_solutions.csv for the
## comparison at the end (the optimizations run without it).
##
## Run from the repo root, with nothing else running:
##   source("reproducibility_scripts/rerun_ansi_objective.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")   # load_all(): picks up R/ changes
source("R/benchmark_targets.R")

OBJ       <- "none"           # ANSI S3.5 SII, no desensitization
STARTS    <- 20
STARTS_RR <- 40
EVAL_LVL  <- 65
ISO_TOL   <- 0.001            # sones; same matching criterion as before
hl_freqs  <- c(250, 500, 1000, 2000, 4000, 8000)
gcols     <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")

out_dir  <- file.path("reproducibility_scripts", "output", "ansi_objective")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(out_dir, "all_solutions.csv")
log_path <- file.path(out_dir, sprintf("rerun_ansi_objective_%s.log", Sys.Date()))
cmp_path <- file.path("reproducibility_scripts", "output", "complete_objective", "all_solutions.csv")

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
if (!OBJ %in% eval(formals(open_nl)$objective_sii))
  stop("open_nl() has no objective_sii option for the ANSI SII; update R/open_nl.R first.")
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
i_obj <- find1("desensitization = objective_sii,")

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
                     cap_override = cap, vent_floor = fl, objective_sii = OBJ)$gain
  tgt <- build_target(hl_freqs, sp, htl, loss, g, EVAL_LVL)
  ll  <- .open_nl_dbg$final_loud
  row <- data.frame(
    set = set, anchor = anchor, profile = profile, budget = budget, floor = fl,
    starts = starts, cap = cap,
    sones_opt   = if (is.null(ll)) NA_real_ else ll[["sones"]],
    sones_model = loudness_of(EVAL_LVL, g, htl, loss)$total,
    objective   = -.open_nl_dbg$final_obj,
    sii_complete = report_sii(tgt, "johnson2011_complete"),
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
cat("\nrerun_ansi_objective.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("objective: %s (ANSI SII) | starts %d (reruns %d) | open_nl_maxit %s\n",
            OBJ, STARTS, STARTS_RR, getOption("open_nl_maxit", "unset")))
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

cat(sprintf("\noptimizations finished at %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
options(open_nl_starts = 3)

## =====================================================================================
## Report
## =====================================================================================
d  <- read.csv(csv_path, stringsAsFactors = FALSE)
cp <- if (file.exists(cmp_path)) read.csv(cmp_path, stringsAsFactors = FALSE) else NULL
r3 <- function(x) sprintf("%+.3f", x)

best <- function(x) {   # highest-starts row per (set, anchor, profile, budget, floor)
  x <- x[x$set %in% c("iso", "sweep") & (is.na(x$budget) | x$budget == 0.5), ]
  k <- paste(x$set, x$anchor, x$profile, ifelse(is.na(x$budget), "NA", x$budget), x$floor)
  x[unlist(lapply(split(seq_len(nrow(x)), k), function(i) i[which.max(x$starts[i])])), ]
}
d <- best(d); if (!is.null(cp)) cp <- best(cp)
get <- function(x, set, anc, p, fl, col) {
  v <- x[x$set == set & x$anchor == anc & x$profile == p & x$floor == fl, col]
  if (length(v) == 1) v else NA_real_
}
fe <- function(x, set, anc, p, col) get(x, set, anc, p, -10, col) - get(x, set, anc, p, 0, col)

cat("\n\n==== ISO-LOUDNESS: ANSI-optimized fittings ====\n")
cat("floor effect under the ANSI SII (what the display shows) and the complete SII,\n")
cat("beside the complete-optimized fittings from rerun_complete_objective.R\n\n")
cat("  prof anc   ANSI-opt: FE ANSI  FE complete  d_sones  |  complete-opt: FE ANSI  FE complete\n")
for (anc in c("on", "off")) for (p in paste0("a", 1:7)) {
  if (is.na(get(d, "iso", anc, p, 0, "sii_ansi"))) next
  cat(sprintf("  %-4s %-4s  %s      %s       %+.4f  |  %s      %s\n", p, anc,
              r3(fe(d, "iso", anc, p, "sii_ansi")), r3(fe(d, "iso", anc, p, "sii_complete")),
              fe(d, "iso", anc, p, "sones_model"),
              if (is.null(cp)) "  NA  " else r3(fe(cp, "iso", anc, p, "sii_ansi")),
              if (is.null(cp)) "  NA  " else r3(fe(cp, "iso", anc, p, "sii_complete"))))
}

cat("\n==== ISO-LOUDNESS: what chasing the display costs ====\n")
cat("complete SII of each fitting; 'cost' = ANSI-optimized minus complete-optimized\n\n")
cat("  prof anc floor   complete SII: ANSI-opt  complete-opt   cost    |  ANSI SII: ANSI-opt  complete-opt\n")
for (anc in c("on", "off")) for (p in paste0("a", 1:7)) for (fl in c(0, -10)) {
  a1 <- get(d, "iso", anc, p, fl, "sii_complete"); if (is.na(a1)) next
  c1 <- if (is.null(cp)) NA_real_ else get(cp, "iso", anc, p, fl, "sii_complete")
  cat(sprintf("  %-4s %-4s %+4d      %.4f       %.4f     %+.4f   |  %.4f      %.4f\n", p, anc, fl,
              a1, c1, a1 - c1, get(d, "iso", anc, p, fl, "sii_ansi"),
              if (is.null(cp)) NA_real_ else get(cp, "iso", anc, p, fl, "sii_ansi")))
}

cat("\n==== TIGHTEST-BUDGET SWEEP: mean floor effect by edge ====\n")
edges <- c(1000, 1500, 2000, 3000)
cat("  edge anc   ANSI-opt: FE ANSI  FE complete  matched  |  complete-opt: FE ANSI  FE complete\n")
for (anc in c("on", "off")) for (e in edges) {
  nms <- unique(d$profile[d$set == "sweep" & edge_of(d$profile) == e])
  f <- function(x, col) mean(sapply(nms, function(nm) fe(x, "sweep", anc, nm, col)), na.rm = TRUE)
  m <- sum(sapply(nms, function(nm) isTRUE(abs(fe(d, "sweep", anc, nm, "sones_opt")) <= ISO_TOL)))
  cat(sprintf("  %-4d %-4s  %s      %s       %d/%d    |  %s      %s\n", e, anc,
              r3(f(d, "sii_ansi")), r3(f(d, "sii_complete")), m, length(nms),
              if (is.null(cp)) "  NA  " else r3(f(cp, "sii_ansi")),
              if (is.null(cp)) "  NA  " else r3(f(cp, "sii_complete"))))
}

cat("\n==== Per audiogram, 0.5 sone, ANSI-optimized (FE ANSI / FE complete; d_sones) ====\n")
for (nm in rownames(FAMILY)) cat(sprintf("  %-10s ON %s / %s  %+.3f  | OFF %s / %s  %+.3f\n", nm,
  r3(fe(d, "sweep", "on", nm, "sii_ansi")), r3(fe(d, "sweep", "on", nm, "sii_complete")),
  fe(d, "sweep", "on", nm, "sones_opt"),
  r3(fe(d, "sweep", "off", nm, "sii_ansi")), r3(fe(d, "sweep", "off", nm, "sii_complete")),
  fe(d, "sweep", "off", nm, "sones_opt")))

cat("\n==== Resolution check: matched anchor-on pairs (sweep + iso), ANSI objective ====\n")
pr <- do.call(rbind, lapply(c(rownames(FAMILY), paste0("a", 1:7)), function(p) {
  set <- if (p %in% rownames(FAMILY)) "sweep" else "iso"
  lc  <- if (set == "sweep") "sones_opt" else "sones_model"
  ds <- fe(d, set, "on", p, lc); if (is.na(ds) || abs(ds) > ISO_TOL) return(NULL)
  data.frame(p = p, d_ansi = fe(d, set, "on", p, "sii_ansi"), d_obj = fe(d, set, "on", p, "objective"))
}))
if (!is.null(pr)) cat(sprintf("  %d matched; %d negative ANSI floor effects (max %.4f); %d with lower objective at -10 dB (max %.3f points)\n",
  nrow(pr), sum(pr$d_ansi < 0), if (any(pr$d_ansi < 0)) max(-pr$d_ansi[pr$d_ansi < 0]) else 0,
  sum(pr$d_obj < -1e-6), if (any(pr$d_obj < -1e-6)) max(-pr$d_obj[pr$d_obj < -1e-6]) else 0))

cat("\n  gains, iso anchor on (0 dB / -10 dB), ANSI-optimized:\n")
for (p in paste0("a", 1:5)) for (fl in c(0, -10)) {
  g <- as.numeric(d[d$set == "iso" & d$anchor == "on" & d$profile == p & d$floor == fl, gcols])
  if (length(g) == 6) cat(sprintf("  %-4s %+4d  %s\n", p, fl, paste(sprintf("%6.1f", g), collapse = "")))
}

cat(sprintf("\ncsv: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Paste everything from '==== ISO-LOUDNESS' down to Claude.\n")
sink(); close(con)
