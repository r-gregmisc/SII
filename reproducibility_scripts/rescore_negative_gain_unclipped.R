## rescore_negative_gain_unclipped.R -------------------------------------------
## Does the SII ever "see" the negative low-frequency insertion gain?
##
## In R/sii.R (line 375), after MPO limiting, the gain applied to the speech
## spectrum is
##     gain <- pmax(final_output - speech, 0)
## so any NEGATIVE insertion gain from a prescription_target is set to 0 dB
## before the SII worksheet is computed. The loudness model inside open_nl()
## does see the negative gain. The consequence: relaxing the floor to -10 dB
## frees loudness budget, but the SII is never charged for (or credited with)
## the lower low-frequency speech level -- no audibility cost in those bands,
## and no release from upward spread of masking.
##
## This script rescores every STORED solution used in Tables 3 and 5 with a
## copy of sii() in which that one line is changed to
##     gain <- final_output - speech
## (everything else, including MPO limiting, unchanged), and reports the floor
## effects both ways. No optimizer is run; takes well under a minute.
##
## First block of output is a sanity check: the "clipped" column must reproduce
## the stored SII values (max |diff| ~ 0). If it does not, stop and tell Claude.
##
## Run from the repo root (can run alongside a long optimization job):
##   source("reproducibility_scripts/rescore_negative_gain_unclipped.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")
source("R/benchmark_targets.R")
suppressMessages(library(dplyr))

ns <- asNamespace("SII")

## ---- patched sii(): negative insertion gain passed through ---------------
## Works before or after the fix in R/sii.R: both variants are built from source.
src <- readLines("R/sii.R")
hit <- grep("^\\s*gain <- (pmax\\(final_output - speech, 0\\)|final_output - speech)\\s*$", src)
stopifnot(length(hit) == 1)
build_variant <- function(line) {
  s <- src; s[hit] <- line
  tmp <- tempfile(fileext = ".R"); writeLines(s, tmp)
  e <- new.env(parent = ns); sys.source(tmp, envir = e)
  f <- e$sii; environment(f) <- ns; f
}
sii_cl <- build_variant("    gain <- pmax(final_output - speech, 0)")
sii_uc <- build_variant("    gain <- final_output - speech")
cat(sprintf("built clipped and unclipped variants of R/sii.R line %d\n\n", hit))

score3 <- function(tgt, fun) {
  one <- function(des) fun(speech = tgt$orig_speech, noise = rep(-50, length(tgt$orig_freq)),
                           threshold = tgt$orig_threshold, loss = tgt$orig_loss,
                           freq = tgt$orig_freq, prescription = tgt, interpolate = TRUE,
                           nal_ldf = FALSE, desensitization = des)$sii
  c(smooth = one("johnson2011_smoothed"), complete = one("johnson2011_complete"),
    ansi = one("none"))
}

hl <- c(250, 500, 1000, 2000, 4000, 8000)
sp <- build_opennl_speech(hl, 65)
gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")

rescore <- function(d, htl_of, loss_of, id_col) {
  out <- lapply(seq_len(nrow(d)), function(i) {
    g   <- as.numeric(d[i, gcols])
    tgt <- build_target(hl, sp, htl_of(d[i, ]), loss_of(d[i, ]), g, 65)
    cl  <- score3(tgt, sii_cl); uc <- score3(tgt, sii_uc)
    data.frame(id = d[[id_col]][i], floor = d$floor[i],
               smooth_cl = cl[["smooth"]], complete_cl = cl[["complete"]], ansi_cl = cl[["ansi"]],
               smooth_uc = uc[["smooth"]], complete_uc = uc[["complete"]], ansi_uc = uc[["ansi"]],
               min_gain = min(g))
  })
  do.call(rbind, out)
}

floor_fx <- function(r) {
  a <- r[r$floor == 0, ]; z <- r[r$floor == -10, ]
  z <- z[match(a$id, z$id), ]
  data.frame(id = a$id,
             smooth_cl = z$smooth_cl - a$smooth_cl, smooth_uc = z$smooth_uc - a$smooth_uc,
             complete_cl = z$complete_cl - a$complete_cl, complete_uc = z$complete_uc - a$complete_uc,
             ansi_cl = z$ansi_cl - a$ansi_cl, ansi_uc = z$ansi_uc - a$ansi_uc)
}
fmt <- function(df) { num <- sapply(df, is.numeric); df[num] <- round(df[num], 4); df }

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
prof_loss <- function(p) if (p == "a6") rep(30, 6) else if (p == "a7") rep(50, 6) else rep(0, 6)
edge_of   <- function(id) as.numeric(sub("^e(\\d+)_s\\d+$", "\\1", id))

odir <- file.path("reproducibility_scripts", "output", "isoloudness")

## ---- 1. Sweep, anchor ON, tightest budget (Table 3 "on") -----------------
sw  <- read.csv(file.path(odir, "sweep_smoothed_rescored.csv"), stringsAsFactors = FALSE)
sw  <- sw[sw$desens == 1 & sw$budget == 0.5, ]
r40 <- read.csv(file.path(odir, "unmatched_tight_rerun_starts40.csv"), stringsAsFactors = FALSE)
sw  <- sw[!sw$audiogram %in% r40$audiogram, c("audiogram", "floor", gcols, "sii_smooth", "sii_complete", "sii_ansi")]
sw  <- rbind(sw, r40[, c("audiogram", "floor", gcols, "sii_smooth", "sii_complete", "sii_ansi")])
r_sw_on <- rescore(sw, function(x) FAMILY[x$audiogram, ], function(x) rep(0, 6), "audiogram")

## ---- 2. Anchor OFF: sweep (part A) and iso-loudness A1-A5 (part B) -------
ao <- read.csv(file.path(odir, "anchor_off_starts20.csv"), stringsAsFactors = FALSE)
aoA <- ao[ao$part == "A", ]; aoB <- ao[ao$part == "B", ]
r_sw_off  <- rescore(aoA, function(x) FAMILY[x$profile, ], function(x) rep(0, 6), "profile")
r_iso_off <- rescore(aoB, function(x) jd2011_targets[[x$profile]]$threshold,
                     function(x) prof_loss(x$profile), "profile")

## ---- 3. Iso-loudness, anchor ON (Tables 4/5 "on") ------------------------
iso <- read.csv("reproducibility_scripts/output/jaaa_audmod/table2_iso_loudness_v2.csv",
                stringsAsFactors = FALSE)
mk <- function(pref, fl) { d <- iso[, c("Profile", paste0(pref, "_G", hl))]
  names(d) <- c("profile", gcols); d$floor <- fl; d }
isoL <- rbind(mk("ONL0", 0), mk("ONL10", -10))
r_iso_on <- rescore(isoL, function(x) jd2011_targets[[x$profile]]$threshold,
                    function(x) prof_loss(x$profile), "profile")

## ---- sanity check: clipped rescoring must reproduce stored values --------
chk <- c(
  sweep_on  = max(abs(c(r_sw_on$smooth_cl - sw$sii_smooth, r_sw_on$complete_cl - sw$sii_complete,
                        r_sw_on$ansi_cl - sw$sii_ansi))),
  sweep_off = max(abs(c(r_sw_off$smooth_cl - aoA$sii_smooth, r_sw_off$complete_cl - aoA$sii_complete,
                        r_sw_off$ansi_cl - aoA$sii_ansi))),
  iso_off   = max(abs(c(r_iso_off$smooth_cl - aoB$sii_smooth, r_iso_off$complete_cl - aoB$sii_complete,
                        r_iso_off$ansi_cl - aoB$sii_ansi))))
cat("==== SANITY CHECK: max |clipped rescore - stored SII| (should be ~0) ====\n")
print(signif(chk, 3))
cat("\n")

## ---- results --------------------------------------------------------------
by_edge <- function(ff) {
  ff$edge <- edge_of(ff$id)
  fmt(aggregate(cbind(smooth_cl, smooth_uc, complete_cl, complete_uc, ansi_cl, ansi_uc) ~ edge,
                data = ff, FUN = mean))
}
cat("==== Table 3 layout: mean floor effect at 0.5 sone, by audible edge ====\n")
cat("_cl = as published (negative gain clipped to 0 in SII); _uc = unclipped\n\n")
cat("-- anchor ON --\n");  print(by_edge(floor_fx(r_sw_on)),  row.names = FALSE)
cat("\n-- anchor OFF --\n"); print(by_edge(floor_fx(r_sw_off)), row.names = FALSE)

cat("\n==== Table 5 layout: iso-loudness floor effect by profile ====\n\n")
cat("-- anchor ON --\n");  print(fmt(floor_fx(r_iso_on)),  row.names = FALSE)
cat("\n-- anchor OFF --\n"); print(fmt(floor_fx(r_iso_off)), row.names = FALSE)

all_ff <- rbind(floor_fx(r_sw_on), floor_fx(r_sw_off), floor_fx(r_iso_on), floor_fx(r_iso_off))
d_max <- max(abs(c(all_ff$smooth_uc - all_ff$smooth_cl, all_ff$complete_uc - all_ff$complete_cl,
                   all_ff$ansi_uc - all_ff$ansi_cl)))
cat(sprintf("\nLargest change in any floor effect from unclipping: %.4f\n", d_max))
cat("(Resolution limit used in the manuscript: 0.006)\n")

write.csv(fmt(rbind(cbind(set = "sweep_on", floor_fx(r_sw_on)), cbind(set = "sweep_off", floor_fx(r_sw_off)),
                    cbind(set = "iso_on", floor_fx(r_iso_on)), cbind(set = "iso_off", floor_fx(r_iso_off)))),
          file.path(odir, "floor_effects_clipped_vs_unclipped.csv"), row.names = FALSE)
cat(sprintf("\ncsv: %s\n", file.path(odir, "floor_effects_clipped_vs_unclipped.csv")))
