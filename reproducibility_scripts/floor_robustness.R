## floor_robustness.R ---------------------------------------------------------------
## Two checks of the floor effect (SII with a -10 dB minimum insertion gain minus
## SII with a 0 dB minimum), optimizing the complete desensitized SII at 65 dB SPL.
##
## Part A. Floor test at the normative ceiling. The loudness cap is set to Lcap,
##   the loudness of unaided speech for a 0 dB HL listener (9.03 sones), instead
##   of the NAL-NL2 loudness or an increment above unaided loudness. Run for the
##   four standard audiograms with audible low-frequency speech (N1, N2, S1, S2),
##   floors 0 and -10 dB, anchor penalty on and off, 20 starts: 16 optimizations.
##
## Part B. Search variability. The optimizer's random-number seed is fixed by the
##   audiogram, so repeated runs are identical and say nothing about how much the
##   solution depends on the random starts. Here the floor comparison is repeated
##   with the default seed and 5 further seeds (20 starts each, anchor on) for
##     - the four 1000 Hz edge sweep audiograms at the 0.5-sone budget, and
##     - N1, N2, S1, S2 at NAL-NL2 loudness (iso-loudness control),
##   giving 6 floor effects per cell: 96 optimizations. The spread across seeds
##   is the empirical search noise.
##
## Total 112 optimizations, roughly 5-6 hours. RESUMES from its CSV: after an
## interrupt just source it again (if it stopped with an error, run sink() once).
## Part A runs first (about 50 minutes) so an early stop still leaves it complete.
##
## Run from the repo root, with nothing else running:
##   source("reproducibility_scripts/floor_robustness.R")
## -----------------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")
source("reproducibility_scripts/bisgaard_profiles.R")

STARTS   <- 20
EVAL_LVL <- 65
N_SEEDS  <- 5                    # extra seeds in Part B (plus the default seed)
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
gcols    <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")
LOSS     <- rep(0, 6)
PROFS4   <- c("N1", "N2", "S1", "S2")
EDGE1000 <- rbind(
  e1000_s20 = c(10, 10, 10, 30,  50,  70),
  e1000_s30 = c(10, 10, 10, 40,  70, 100),
  e1000_s40 = c(10, 10, 10, 50,  90, 110),
  e1000_s50 = c(10, 10, 10, 60, 110, 110))

out_dir  <- file.path("reproducibility_scripts", "output", "floor_robustness")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(out_dir, "solutions.csv")
log_path <- file.path(out_dir, sprintf("floor_robustness_%s.log", Sys.Date()))

## ---- preconditions -------------------------------------------------------------
if (!identical(eval(formals(open_nl)$objective_sii)[1], "johnson2011_complete"))
  stop("open_nl()'s objective_sii default is not johnson2011_complete.")
if (!bisgaard_nal_ready()) stop("NAL-NL2 gains missing from bisgaard_profiles.R.")

## ---- instrumented open_nl(): loudness logged, anchor on/off, seed overridable ----
## Anchored by pattern, not line number. The seed line is changed only to read an
## option; with the option unset it uses the package's own default seed.
src <- readLines("R/open_nl.R")
find1 <- function(pattern) {
  i <- grep(pattern, src, fixed = TRUE)
  if (length(i) != 1) stop(sprintf("expected one match in R/open_nl.R for: %s (found %d)", pattern, length(i)))
  i
}
seed_line <- "set.seed(as.integer(sum(threshold, na.rm=TRUE) * 100 + eval_level))"
i_cap  <- find1("if (!is.null(cap_override)) dynamic_cap <- cap_override")
i_fin  <- find1("clamped_shifts <- pmax(-60, pmin(30, best_shifts))")
i_anc  <- find1("anchor_penalty <- sum(abs(shifts)) * 0.1")
i_seed <- find1(seed_line)
instrument <- function(anchor_on) {
  s2 <- src
  s2[i_seed] <- sub(seed_line,
    "set.seed(getOption('open_nl_seed', as.integer(sum(threshold, na.rm=TRUE) * 100 + eval_level)))",
    s2[i_seed], fixed = TRUE)
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

## ---- inputs ----------------------------------------------------------------------
sp    <- build_opennl_speech(hl_freqs, EVAL_LVL)
LCAP  <- lcap(EVAL_LVL)
nal <- lapply(setNames(PROFS4, PROFS4), function(p) {
  g6 <- get_bisgaard_nalnl2(p, hl_freqs, EVAL_LVL)
  th <- bisgaard_profiles[[p]]$threshold
  t  <- build_target(hl_freqs, sp, th, LOSS, g6, EVAL_LVL)
  list(th = th, gain = g6, loud = loudness_of(EVAL_LVL, g6, th, LOSS)$total,
       L0 = loudness_of(EVAL_LVL, rep(0, 6), th, LOSS)$total,
       complete = report_sii(t, "johnson2011_complete"), ansi = report_sii(t, "none"))
})
L0e <- sapply(rownames(EDGE1000), function(nm)
  loudness_of(EVAL_LVL, rep(0, 6), EDGE1000[nm, ], LOSS)$total)
thr_of <- function(p) if (p %in% PROFS4) nal[[p]]$th else EDGE1000[p, ]
default_seed <- function(th) as.integer(sum(th) * 100 + EVAL_LVL)

## ---- one optimization, scored and saved ------------------------------------------
done <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors = FALSE) else NULL
key  <- function(part, cond, anchor, profile, seed_id, floor) paste(part, cond, anchor, profile, seed_id, floor)
key_done <- if (is.null(done)) character(0) else
  key(done$part, done$cond, done$anchor, done$profile, done$seed_id, done$floor)
n_todo <- 16 + 2 * (N_SEEDS + 1) * (nrow(EDGE1000) + length(PROFS4)) - length(key_done)
t_start <- Sys.time(); n_new <- 0

run_one <- function(part, cond, anchor, profile, cap, seed_id, fl) {
  k <- key(part, cond, anchor, profile, seed_id, fl)
  if (k %in% key_done) return(invisible(NULL))
  th <- thr_of(profile)
  seed <- if (seed_id == 0) default_seed(th) else default_seed(th) + 7919L * seed_id
  options(open_nl_starts = STARTS, open_nl_seed = seed)
  .open_nl_dbg$last_loud <- NULL; .open_nl_dbg$final_loud <- NULL; .open_nl_dbg$final_obj <- NA_real_
  g <- onl[[anchor]](speech = EVAL_LVL, threshold = th, freq = hl_freqs, loss = LOSS,
                     cap_override = cap, vent_floor = fl)$gain
  options(open_nl_seed = NULL)
  tgt <- build_target(hl_freqs, sp, th, LOSS, g, EVAL_LVL)
  ll  <- .open_nl_dbg$final_loud
  row <- data.frame(part = part, cond = cond, anchor = anchor, profile = profile,
                    seed_id = seed_id, seed = seed, floor = fl, starts = STARTS, cap = cap,
                    sones_opt   = if (is.null(ll)) NA_real_ else ll[["sones"]],
                    sones_model = loudness_of(EVAL_LVL, g, th, LOSS)$total,
                    objective   = -.open_nl_dbg$final_obj,
                    sii_complete = report_sii(tgt, "johnson2011_complete"),
                    sii_ansi     = report_sii(tgt, "none"),
                    g250 = g[1], g500 = g[2], g1000 = g[3], g2000 = g[4], g4000 = g[5], g8000 = g[6],
                    stringsAsFactors = FALSE)
  write.table(row, csv_path, sep = ",", row.names = FALSE,
              col.names = !file.exists(csv_path), append = file.exists(csv_path))
  key_done <<- c(key_done, k); n_new <<- n_new + 1
  el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  cat(sprintf("  %s %-6s %-3s %-9s seed%d fl%+3d  sones %6.3f / cap %6.3f  complete %.4f  ANSI %.4f  [%d/%d, %.0fm, ~%.1fh left]\n",
              part, cond, anchor, profile, seed_id, fl, row$sones_opt, cap, row$sii_complete,
              row$sii_ansi, n_new, n_todo, el, (n_todo - n_new) * el / n_new / 60))
  invisible(row)
}

## ---- run -----------------------------------------------------------------------------
con <- file(log_path, open = "at"); sink(con, split = TRUE)
cat("\nfloor_robustness.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n")
cat(sprintf("Lcap(65) = %.3f sones | starts %d | extra seeds %d | already done %d | to do %d\n\n",
            LCAP, STARTS, N_SEEDS, length(key_done), n_todo))

cat("==== Part A: cap = normative ceiling ====\n")
for (anc in c("on", "off")) for (p in PROFS4) for (fl in c(0, -10))
  run_one("A", "Lcap", anc, p, LCAP, 0, fl)

cat("\n==== Part B: seeds ====\n")
for (s in 0:N_SEEDS) {
  for (nm in rownames(EDGE1000)) for (fl in c(0, -10))
    run_one("B", "sweep", "on", nm, L0e[[nm]] + 0.5, s, fl)
  for (p in PROFS4) for (fl in c(0, -10))
    run_one("B", "iso", "on", p, nal[[p]]$loud, s, fl)
}
options(open_nl_starts = 3, open_nl_seed = NULL)

## ---- report ----------------------------------------------------------------------------
d <- read.csv(csv_path, stringsAsFactors = FALSE)
pick <- function(part, cond, anc, p, s, fl, col) {
  v <- d[d$part == part & d$cond == cond & d$anchor == anc & d$profile == p &
         d$seed_id == s & d$floor == fl, col]
  if (length(v) == 1) v else NA_real_
}
negb <- function(part, cond, anc, p, s) {
  g <- unlist(d[d$part == part & d$cond == cond & d$anchor == anc & d$profile == p &
                d$seed_id == s & d$floor == -10, gcols])
  b <- hl_freqs[g < -0.05]; if (length(b)) paste(b, collapse = "/") else "none"
}

cat("\n\n==== PART A: floor effect with the cap at the normative ceiling (Lcap) ====\n")
cat(sprintf("  Lcap = %.2f sones. Budget = Lcap - L0; NAL-NL2 uses (NAL loudness - L0) of it.\n\n", LCAP))
cat("  prof  L0     budget  NAL used | anc  complete 0dB  -10dB   floor   ANSI floor  sones 0 / -10    neg bands\n")
for (p in PROFS4) for (anc in c("on", "off")) {
  c0 <- pick("A", "Lcap", anc, p, 0, 0, "sii_complete"); c10 <- pick("A", "Lcap", anc, p, 0, -10, "sii_complete")
  a0 <- pick("A", "Lcap", anc, p, 0, 0, "sii_ansi");     a10 <- pick("A", "Lcap", anc, p, 0, -10, "sii_ansi")
  cat(sprintf("  %-4s  %5.2f  %5.2f   %5.2f   | %-3s  %.4f      %.4f  %+.4f  %+.4f     %6.3f / %6.3f  %s\n",
              p, nal[[p]]$L0, LCAP - nal[[p]]$L0, nal[[p]]$loud - nal[[p]]$L0, anc, c0, c10, c10 - c0,
              a10 - a0, pick("A", "Lcap", anc, p, 0, 0, "sones_opt"),
              pick("A", "Lcap", anc, p, 0, -10, "sones_opt"), negb("A", "Lcap", anc, p, 0)))
}
cat("\n  complete SII at the Lcap cap vs NAL-NL2 (anchor on, 0 dB floor):\n")
for (p in PROFS4)
  cat(sprintf("  %-4s  NAL-NL2 %.4f   Open-NL at Lcap %.4f   (%+.4f)\n", p, nal[[p]]$complete,
              pick("A", "Lcap", "on", p, 0, 0, "sii_complete"),
              pick("A", "Lcap", "on", p, 0, 0, "sii_complete") - nal[[p]]$complete))

cat("\n\n==== PART B: floor effect across seeds (anchor on, 20 starts each) ====\n")
cat("  complete-SII floor effect per seed (seed 0 = package default), then mean, SD, range;\n")
cat("  'best' = floor effect between the best-objective solutions over all seeds at each floor.\n\n")
cells <- c(paste("sweep", rownames(EDGE1000)), paste("iso", PROFS4))
fe_all <- c(); sd_fixed <- c()
for (cl in cells) {
  cond <- sub(" .*", "", cl); p <- sub(".* ", "", cl)
  fe <- sapply(0:N_SEEDS, function(s)
    pick("B", cond, "on", p, s, -10, "sii_complete") - pick("B", cond, "on", p, s, 0, "sii_complete"))
  x  <- d[d$part == "B" & d$cond == cond & d$profile == p, ]
  b0 <- x[x$floor == 0, ][which.max(x$objective[x$floor == 0]), ]
  b10 <- x[x$floor == -10, ][which.max(x$objective[x$floor == -10]), ]
  cat(sprintf("  %-15s %s | mean %+.4f  SD %.4f  range %+.4f..%+.4f | best %+.4f\n", cl,
              paste(sprintf("%+.4f", fe), collapse = " "), mean(fe, na.rm = TRUE), sd(fe, na.rm = TRUE),
              min(fe, na.rm = TRUE), max(fe, na.rm = TRUE), b10$sii_complete - b0$sii_complete))
  fe_all <- c(fe_all, fe - mean(fe, na.rm = TRUE))
  for (fl in c(0, -10)) sd_fixed <- c(sd_fixed, sd(x$sii_complete[x$floor == fl], na.rm = TRUE))
}
cat(sprintf("\n  pooled within-cell SD of the floor effect: %.4f  (2 SD = %.4f)\n",
            sd(fe_all, na.rm = TRUE) * sqrt(length(fe_all) / (length(fe_all) - length(cells))),
            2 * sd(fe_all, na.rm = TRUE) * sqrt(length(fe_all) / (length(fe_all) - length(cells)))))
cat(sprintf("  median SD of the complete SII across seeds at a fixed floor: %.4f (max %.4f)\n",
            median(sd_fixed, na.rm = TRUE), max(sd_fixed, na.rm = TRUE)))
cat(sprintf("  loudness matching across all Part B pairs: max |d sones| = %.4f\n",
            max(abs(sapply(split(d[d$part == "B", ], list(d$cond[d$part == "B"], d$profile[d$part == "B"],
                                                           d$seed_id[d$part == "B"]), drop = TRUE),
                           function(x) diff(x$sones_opt[order(x$floor)]))), na.rm = TRUE)))

cat(sprintf("\ncsv: %s\nfinished at: %s\n", csv_path, format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("Paste everything from '==== PART A' down to Claude.\n")
sink(); close(con)
