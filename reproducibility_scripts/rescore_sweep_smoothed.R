## rescore_sweep_smoothed.R ---------------------------------------------------
## Rescores the audiogram-family sweep under three SII metrics, using only the
## solutions that were optimized on the smoothed desensitized SII.
##
## Why: rebuild_isoloudness_20_naldf_off.R passed desensitization_scale = ds to
## the OPTIMIZER (line 152). In sii.R line 547,
##     Ki <- (1 - scale) * Ki_raw + scale * Ki_desens
## so ds = 0 rows were optimized on raw ANSI SII and ds = 0.5 rows on a 50/50
## blend. Only ds = 1 rows were optimized on the full smoothed SII, which is the
## intended design. This script keeps those rows and scores their stored gains
## three ways, matching the Table 3 design (optimize once on smoothed, score
## on smoothed, complete, and ANSI). No optimization is run; takes seconds.
##
## Run from the repo root:  source("reproducibility_scripts/rescore_sweep_smoothed.R")
## -----------------------------------------------------------------------------

source("reproducibility_scripts/helpers_jaaa.R")

EVAL_LVL <- 65
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
in_csv   <- "reproducibility_scripts/output/isoloudness/isoloudness_starts20_naldf_off.csv"
out_csv  <- "reproducibility_scripts/output/isoloudness/sweep_smoothed_rescored.csv"

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

d  <- read.csv(in_csv, stringsAsFactors = FALSE)
d  <- d[d$desens == 1, ]
stopifnot(nrow(d) == 128)
sp <- build_opennl_speech(hl_freqs, EVAL_LVL)

gcols <- c("g250", "g500", "g1000", "g2000", "g4000", "g8000")
d$sii_smooth <- d$sii_complete <- d$sii_ansi <- NA_real_
for (i in seq_len(nrow(d))) {
  htl6 <- FAMILY[d$audiogram[i], ]
  g    <- as.numeric(d[i, gcols])
  tgt  <- build_target(hl_freqs, sp, htl6, rep(0, 6), g, EVAL_LVL)
  d$sii_smooth[i]   <- report_sii(tgt, "johnson2011_smoothed", desensitization_scale = 1)
  d$sii_complete[i] <- report_sii(tgt, "johnson2011_complete", desensitization_scale = 1)
  d$sii_ansi[i]     <- report_sii(tgt, "none")
}

## Self-check: rescored smoothed SII must reproduce the stored value.
max_dev <- max(abs(d$sii_smooth - d$sii))
cat(sprintf("self-check: max |rescored smoothed - stored| = %.2e\n", max_dev))
if (max_dev > 1e-8) stop("Rescoring does not reproduce stored SII; do not use these results.")

write.csv(d, out_csv, row.names = FALSE)

## ---- paired floor contrast --------------------------------------------------
pair <- do.call(rbind, lapply(split(d, list(d$audiogram, d$budget), drop = TRUE), function(x) {
  a <- x[x$floor == 0, ]; z <- x[x$floor == -10, ]
  data.frame(audiogram = a$audiogram, edge = a$edge, slope = a$slope, budget = a$budget,
             d_sones = z$sones - a$sones,
             d_smooth = z$sii_smooth - a$sii_smooth,
             d_complete = z$sii_complete - a$sii_complete,
             d_ansi = z$sii_ansi - a$sii_ansi)
}))
pair$matched <- abs(pair$d_sones) <= 0.001

cat(sprintf("\npairs %d, matched in loudness %d\n", nrow(pair), sum(pair$matched)))

m <- pair[pair$matched, ]
neg <- abs(m$d_smooth[m$d_smooth < 0])
cat(sprintf("resolution limit (smoothed, the optimized metric): %d negatives, median %.4f, max %.4f\n",
            length(neg), median(neg), max(neg)))
cat("(negatives under complete or ANSI are NOT noise: those metrics were not optimized)\n")

for (met in c("d_smooth", "d_complete", "d_ansi")) {
  cat(sprintf("\n==== Mean floor effect, %s, by edge (rows) and budget (cols) ====\n", met))
  print(round(tapply(pair[[met]], list(pair$edge, pair$budget), mean), 4))
}

cat("\n==== Tightest budget (0.5), matched pairs only ====\n")
t5 <- m[m$budget == 0.5, ]
print(round(aggregate(cbind(d_smooth, d_complete, d_ansi) ~ edge, data = t5, FUN = mean), 4))
print(table(edge = t5$edge))

cat(sprintf("\nwrote %s\n", out_csv))
