## rerun_bisgaard_profiles.R ------------------------------------------------------
## Profile-based analyses on the 10 Bisgaard et al. (2010) standard audiograms
## (reproducibility_scripts/bisgaard_profiles.R), replacing the earlier A1-A7.
##
## Part 1 (runs now, seconds): loudness budget decomposition, unaided loudness L0
##   against the normal-hearing ceiling Lcap at 50, 65 and 80 dB SPL (Table 2,
##   Figure 1).
## Part 2 (runs once the NAL-NL2 gains are entered in bisgaard_profiles.R):
##   iso-loudness control at 65 dB SPL, capped at each profile's NAL-NL2
##   loudness, floors 0 and -10 dB, anchor penalty on and off, with the optimizer
##   maximizing (a) the complete desensitized SII and (b) the ANSI SII.
##   80 optimizations at 20 starts, roughly 4 hours. Every solution is scored under
##   the complete and ANSI SII.
##
## If the gains are not yet entered, the script stops after Part 1 with a message.
## Part 2 RESUMES from its CSV: after an interrupt, just source it again (if it
## stopped with an error, run  sink()  once at the prompt first).
##
## Run from the repo root, with no other optimization running:
##   source("reproducibility_scripts/rerun_bisgaard_profiles.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")
source("reproducibility_scripts/bisgaard_profiles.R")

STARTS   <- 20
EVAL_LVL <- 65
ISO_TOL  <- 0.001
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
gcols    <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")
PROFS    <- names(bisgaard_profiles)
LOSS     <- rep(0, 6)

out_dir  <- file.path("reproducibility_scripts", "output", "bisgaard")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
bud_path <- file.path(out_dir, "budget_decomposition.csv")
csv_path <- file.path(out_dir, "iso_solutions.csv")
log_path <- file.path(out_dir, sprintf("rerun_bisgaard_profiles_%s.log", Sys.Date()))

s <- readLines("R/sii.R")
if (!any(grepl("^\\s*gain <- final_output - speech\\s*$", s)))
  stop("R/sii.R does not carry the negative-gain fix.")
if (!all(c("johnson2011_desensitized", "none") %in% eval(formals(open_nl)$objective_sii)))
  stop("open_nl() lacks the objective_sii options needed; update R/open_nl.R first.")

con <- file(log_path, open = "at"); sink(con, split = TRUE)
cat("\nrerun_bisgaard_profiles.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

## =====================================================================================
## Part 1: budget decomposition
## =====================================================================================
bud <- do.call(rbind, lapply(c("Normal", PROFS), function(p) {
  th <- if (p == "Normal") rep(0, 6) else bisgaard_profiles[[p]]$threshold
  do.call(rbind, lapply(c(50, 65, 80), function(lvl) {
    L0 <- loudness_of(lvl, rep(0, 6), th, LOSS)$total; Lc <- lcap(lvl)
    data.frame(Profile = p, Level = lvl, L0 = L0, Lcap = Lc, Budget = Lc - L0,
               Ratio = L0 / Lc, stringsAsFactors = FALSE)
  }))
}))
write.csv(bud, bud_path, row.names = FALSE)
cat("==== PART 1: budget decomposition (L0 as % of Lcap) ====\n")
cat(sprintf("  Lcap: %.2f / %.2f / %.2f sones at 50 / 65 / 80 dB SPL\n\n",
            lcap(50), lcap(65), lcap(80)))
cat("  prof   thresholds (250-8000 Hz)            L0 50    L0 65    L0 80   | % 50   % 65   % 80\n")
for (p in c("Normal", PROFS)) {
  b <- bud[bud$Profile == p, ]
  th <- if (p == "Normal") rep(0, 6) else bisgaard_profiles[[p]]$threshold
  cat(sprintf("  %-6s %-34s %6.2f   %6.2f   %6.2f   | %5.1f  %5.1f  %5.1f\n", p,
              paste(th, collapse = " "), b$L0[1], b$L0[2], b$L0[3],
              100 * b$Ratio[1], 100 * b$Ratio[2], 100 * b$Ratio[3]))
}
cat(sprintf("\ncsv: %s\n", bud_path))

if (!bisgaard_nal_ready()) {
  cat("\nNAL-NL2 gains are not yet entered in reproducibility_scripts/bisgaard_profiles.R.\n")
  cat("Part 2 (iso-loudness control) skipped. Paste the output above to Claude.\n")
  sink(); close(con)
} else {

## =====================================================================================
## Part 2: iso-loudness control, both objectives
## =====================================================================================
src <- readLines("R/open_nl.R")
find1 <- function(pattern) {
  i <- grep(pattern, src, fixed = TRUE)
  if (length(i) != 1) stop(sprintf("expected one match in R/open_nl.R for: %s (found %d)", pattern, length(i)))
  i
}
i_cap <- find1("if (!is.null(cap_override)) dynamic_cap <- cap_override")
i_fin <- find1("clamped_shifts <- pmax(-60, pmin(30, best_shifts))")
i_anc <- find1("anchor_penalty <- sum(abs(shifts)) * 0.1")
instrument <- function(anchor_on) {
  s2 <- src
  if (!anchor_on) s2[i_anc] <- sub("* 0.1", "* 0", s2[i_anc], fixed = TRUE)
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

sp  <- build_opennl_speech(hl_freqs, EVAL_LVL)
nal <- lapply(setNames(PROFS, PROFS), function(p) {
  g6 <- get_bisgaard_nalnl2(p, hl_freqs, EVAL_LVL)
  th <- bisgaard_profiles[[p]]$threshold
  t  <- build_target(hl_freqs, sp, th, LOSS, g6, EVAL_LVL)
  list(th = th, gain = g6, loud = loudness_of(EVAL_LVL, g6, th, LOSS)$total,
       complete = report_sii(t, "johnson2011_desensitized"), ansi = report_sii(t, "none"))
})

done <- if (file.exists(csv_path)) read.csv(csv_path, stringsAsFactors = FALSE) else NULL
key  <- function(obj, anchor, profile, floor) paste(obj, anchor, profile, floor)
key_done <- if (is.null(done)) character(0) else key(done$objective_sii, done$anchor, done$profile, done$floor)
t_start <- Sys.time(); n_new <- 0
n_todo <- 2 * 2 * length(PROFS) * 2 - length(key_done)
options(open_nl_starts = STARTS)

cat(sprintf("\n\n==== PART 2: iso-loudness control, %d optimizations to do ====\n", n_todo))
for (anc in c("on", "off")) for (obj in c("johnson2011_desensitized", "none")) for (p in PROFS) for (fl in c(0, -10)) {
  k <- key(obj, anc, p, fl); if (k %in% key_done) next
  .open_nl_dbg$last_loud <- NULL; .open_nl_dbg$final_loud <- NULL; .open_nl_dbg$final_obj <- NA_real_
  g <- onl[[anc]](speech = EVAL_LVL, threshold = nal[[p]]$th, freq = hl_freqs, loss = LOSS,
                  cap_override = nal[[p]]$loud, vent_floor = fl, objective_sii = obj)$gain
  tgt <- build_target(hl_freqs, sp, nal[[p]]$th, LOSS, g, EVAL_LVL)
  ll  <- .open_nl_dbg$final_loud
  row <- data.frame(objective_sii = obj, anchor = anc, profile = p, floor = fl, starts = STARTS,
                    cap = nal[[p]]$loud,
                    sones_opt   = if (is.null(ll)) NA_real_ else ll[["sones"]],
                    sones_model = loudness_of(EVAL_LVL, g, nal[[p]]$th, LOSS)$total,
                    objective   = -.open_nl_dbg$final_obj,
                    sii_complete = report_sii(tgt, "johnson2011_desensitized"),
                    sii_ansi     = report_sii(tgt, "none"),
                    g250 = g[1], g500 = g[2], g1000 = g[3], g2000 = g[4], g4000 = g[5], g8000 = g[6],
                    stringsAsFactors = FALSE)
  write.table(row, csv_path, sep = ",", row.names = FALSE,
              col.names = !file.exists(csv_path), append = file.exists(csv_path))
  key_done <- c(key_done, k); n_new <- n_new + 1
  el <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))
  cat(sprintf("  %-8s %-3s %-3s fl%+3d  sones %6.3f / cap %6.3f  complete %.4f  ANSI %.4f  [%d/%d, %.0fm, ~%.1fh left]\n",
              if (obj == "none") "ANSI" else "complete", anc, p, fl, row$sones_opt, row$cap,
              row$sii_complete, row$sii_ansi, n_new, n_todo, el, (n_todo - n_new) * el / n_new / 60))
}
options(open_nl_starts = 3)

## ---- report ------------------------------------------------------------------------
d <- read.csv(csv_path, stringsAsFactors = FALSE)
get <- function(obj, anc, p, fl, col) {
  v <- d[d$objective_sii == obj & d$anchor == anc & d$profile == p & d$floor == fl, col]
  if (length(v) == 1) v else NA_real_
}
fe <- function(obj, anc, p, col) get(obj, anc, p, -10, col) - get(obj, anc, p, 0, col)
r3 <- function(x) sprintf("%+.3f", x)

cat("\n\n==== NAL-NL2 at 65 dB SPL ====\n")
cat("  prof   loudness  % of Lcap  above L0   complete SII  ANSI SII\n")
L0_65 <- bud[bud$Level == 65, ]
for (p in PROFS) cat(sprintf("  %-4s   %6.2f    %5.1f     %+5.2f      %.3f       %.3f\n", p,
  nal[[p]]$loud, 100 * nal[[p]]$loud / lcap(65), nal[[p]]$loud - L0_65$L0[L0_65$Profile == p],
  nal[[p]]$complete, nal[[p]]$ansi))

cat("\n==== TABLE 4 (complete objective, anchor on): complete SII ====\n")
cat("  prof  NAL SII  ONL 0 dB  ONL -10 dB  optimizer  floor    d_sones  neg bands (-10)\n")
for (p in PROFS) {
  c0 <- get("johnson2011_desensitized", "on", p, 0, "sii_complete")
  c10 <- get("johnson2011_desensitized", "on", p, -10, "sii_complete")
  g <- as.numeric(d[d$objective_sii == "johnson2011_desensitized" & d$anchor == "on" & d$profile == p & d$floor == -10, gcols])
  cat(sprintf("  %-4s  %.3f    %.3f     %.3f      %s    %s   %+.4f  %s\n", p, nal[[p]]$complete, c0, c10,
              r3(c0 - nal[[p]]$complete), r3(c10 - c0), fe("johnson2011_desensitized", "on", p, "sones_model"),
              if (length(g) == 6 && any(g < -0.001)) paste(hl_freqs[g < -0.001], collapse = "/") else "none"))
}
cat("\n  optimizer effect under ANSI (complete objective, anchor on):\n")
for (p in PROFS) cat(sprintf("  %-4s  %s\n", p, r3(get("johnson2011_desensitized", "on", p, 0, "sii_ansi") - nal[[p]]$ansi)))

cat("\n==== TABLE 5: floor effect, complete-objective fittings ====\n")
cat("  prof  complete on  complete off  ANSI on   ANSI off   d_sones on / off\n")
for (p in PROFS) cat(sprintf("  %-4s  %s       %s        %s    %s     %+.4f / %+.4f\n", p,
  r3(fe("johnson2011_desensitized", "on", p, "sii_complete")), r3(fe("johnson2011_desensitized", "off", p, "sii_complete")),
  r3(fe("johnson2011_desensitized", "on", p, "sii_ansi")), r3(fe("johnson2011_desensitized", "off", p, "sii_ansi")),
  fe("johnson2011_desensitized", "on", p, "sones_model"), fe("johnson2011_desensitized", "off", p, "sones_model")))

cat("\n==== ANSI-tuned fittings: floor effect on the display vs after desensitization ====\n")
cat("  prof  ANSI on  complete on  |  ANSI off  complete off  |  d_sones on / off\n")
for (p in PROFS) cat(sprintf("  %-4s  %s   %s       |  %s    %s        |  %+.4f / %+.4f\n", p,
  r3(fe("none", "on", p, "sii_ansi")), r3(fe("none", "on", p, "sii_complete")),
  r3(fe("none", "off", p, "sii_ansi")), r3(fe("none", "off", p, "sii_complete")),
  fe("none", "on", p, "sones_model"), fe("none", "off", p, "sones_model")))

cat("\n==== Complete SII reached: ANSI-tuned vs complete-tuned (anchor on) ====\n")
for (p in PROFS) for (fl in c(0, -10)) cat(sprintf("  %-4s fl%+3d  %.4f vs %.4f  (%+.4f)\n", p, fl,
  get("none", "on", p, fl, "sii_complete"), get("johnson2011_desensitized", "on", p, fl, "sii_complete"),
  get("none", "on", p, fl, "sii_complete") - get("johnson2011_desensitized", "on", p, fl, "sii_complete")))

cat("\n==== Search check: matched pairs with lower objective at -10 dB ====\n")
for (obj in c("johnson2011_desensitized", "none")) for (anc in c("on", "off")) {
  x <- sapply(PROFS, function(p) c(ds = fe(obj, anc, p, "sones_model"), dobj = fe(obj, anc, p, "objective")))
  m <- !is.na(x["ds", ]) & abs(x["ds", ]) <= ISO_TOL
  bad <- m & x["dobj", ] < -1e-6
  cat(sprintf("  %-8s %-3s  matched %d/%d; lower objective in %d (max %.3f points)\n",
              if (obj == "none") "ANSI" else "complete", anc, sum(m), length(PROFS), sum(bad),
              if (any(bad)) max(-x["dobj", bad]) else 0))
}

cat(sprintf("\ncsv: %s\n", csv_path))
cat("finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Paste everything from '==== PART 1' down to Claude.\n")
sink(); close(con)
}
