## audit_tone_anchor.R -------------------------------------------------------
## Is the 1 kHz / 40 dB SPL anchor really 0.32 sones, or did the tone lose
## energy being resampled onto the engine's FFT grid?
##
## At fs = 32000 and N = 8192 the bin width is 3.90625 Hz, and 1000 Hz falls
## exactly on bin 256. The earlier check built the tone on a 10 Hz grid, which
## does not align, and its answer moved with bin count (0.3161 -> 0.4566),
## which is the signature of resampling loss rather than a scale error.
##
## This sweeps the input grid spacing from 10 Hz down to sub-bin resolution.
## A smooth spectrum (speech at 65 dB SPL, known to give 9.0333 sones) is run
## at every spacing as a control: it should not move. If the tone rises toward
## 1.0 while the control stays flat, the anchor is fine and the earlier result
## was an artefact of the input path.
##
## Run from the repository root. No optimizer, no options() changes, writes
## only its own log - safe to run beside a long optimization job.
## -----------------------------------------------------------------------------

devtools::load_all(quiet = TRUE)

log_path <- file.path("reproducibility_scripts", "output",
                      sprintf("audit_tone_anchor_%s.log", Sys.Date()))
dir.create(dirname(log_path), recursive = TRUE, showWarnings = FALSE)
con <- file(log_path, open = "wt"); sink(con, split = TRUE)

cat("audit_tone_anchor.R\n")
cat("run at:   ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("git HEAD: ", tryCatch(system("git rev-parse --short HEAD", intern = TRUE),
                           error = function(e) "unavailable"), "\n\n")

FS <- 32000; NFFT <- 8192
BIN <- FS / NFFT                      # 3.90625 Hz
hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
ltass_65 <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)

cat(sprintf("FFT bin width: %.6f Hz | 1000 Hz is bin %.3f\n\n", BIN, 1000 / BIN))

loud <- function(freq, level, htl6 = rep(0, 6)) {
  SII:::calculate_loudness_audmod(
    freq = freq, level_dB_per_Hz = level,
    audiogram_freq = hl_freqs, audiogram_HL = htl6,
    fs = FS, N = NFFT)$total
}

## ---- Part 0: how does the wrapper build its input? -----------------------
## Needed to write the definitive native-resolution test if this one is
## inconclusive.

cat("==== PART 0: calculate_loudness_audmod source ====\n\n")
print(SII:::calculate_loudness_audmod)

## ---- spectrum builders, parameterised by grid spacing --------------------

speech_on_grid <- function(df, lo = 10, hi = 23990) {
  f <- seq(lo, hi, by = df)
  l <- approx(log10(hl_freqs), ltass_65, log10(f), rule = 2)$y
  under <- f < hl_freqs[1]; over <- f > hl_freqs[6]
  l[under] <- ltass_65[1] - 24 * log2(hl_freqs[1] / f[under])
  l[over]  <- ltass_65[6] - 24 * log2(f[over] / hl_freqs[6])
  list(freq = f, level = l)
}

## One tone of `spl` dB SPL total, as a per-Hz density in a single grid bin.
tone_on_grid <- function(df, f0 = 1000, spl = 40, lo = 10, hi = 23990,
                         floor_dB = -200) {
  f <- seq(lo, hi, by = df)
  l <- rep(floor_dB, length(f))
  i <- which.min(abs(f - f0))
  l[i] <- spl - 10 * log10(df)
  list(freq = f, level = l, placed_at = f[i])
}

## ---- Part 1: grid convergence -------------------------------------------

cat("\n\n==== PART 1: does the answer depend on input grid spacing? ====\n\n")
cat("   speech should stay at 9.0333; the tone should approach 1.0 if the\n")
cat("   earlier 0.3161 was resampling loss.\n\n")
cat("  spacing (Hz)   bins/FFTbin   speech (sones)   tone placed at   tone (sones)\n")

spacings <- c(10, 5, BIN, BIN / 2, BIN / 4, 1, 0.5)
for (df in spacings) {
  sp <- speech_on_grid(df)
  tn <- tone_on_grid(df)
  cat(sprintf("  %10.5f   %10.2f   %14.4f   %14.4f   %12.4f\n",
              df, BIN / df, loud(sp$freq, sp$level),
              tn$placed_at, loud(tn$freq, tn$level)))
}

## ---- Part 2: alignment ---------------------------------------------------
## 1000 Hz sits exactly on a bin centre; 1100 Hz does not. If placement
## relative to the bin grid matters, that is resampling, not the model.

cat("\n\n==== PART 2: on-bin vs off-bin placement (spacing = bin/4) ====\n\n")
df <- BIN / 4
for (f0 in c(1000, 1000 + BIN / 2, 1100, 1100 + BIN / 2)) {
  tn <- tone_on_grid(df, f0 = f0)
  cat(sprintf("  tone at %9.4f Hz (placed %9.4f): %.4f sones\n",
              f0, tn$placed_at, loud(tn$freq, tn$level)))
}

## ---- Part 3: the anchor and the growth law at fine resolution ------------

cat("\n\n==== PART 3: level series at spacing = bin/4 ====\n\n")
cat("  1 kHz tone, normal hearing. 40 dB SPL should be 1.0 sone,\n")
cat("  and loudness should roughly double per 10 dB above it.\n\n")
prev <- NA_real_
for (L in seq(0, 100, by = 10)) {
  tn <- tone_on_grid(BIN / 4, spl = L)
  v <- loud(tn$freq, tn$level)
  cat(sprintf("  %3d dB SPL: %10.4f sones   ratio %s\n", L, v,
              if (is.na(prev) || prev < 1e-9) "--" else sprintf("%.3f", v / prev)))
  prev <- v
}

## ---- Part 4: narrowband control -----------------------------------------
## A 1-ERB-wide band at 1 kHz (about 133 Hz) carrying the same total power
## should give a similar loudness to the tone. If the tone is far below the
## band, the tone representation is still lossy.

cat("\n\n==== PART 4: tone vs 1-ERB band, same total power ====\n\n")
erb <- 24.7 * (4.37 * 1 + 1)          # ~133 Hz at 1 kHz
df <- BIN / 4
f <- seq(10, 23990, by = df)
for (bw in c(0, erb / 4, erb, erb * 2)) {
  l <- rep(-200, length(f))
  idx <- if (bw == 0) which.min(abs(f - 1000)) else which(abs(f - 1000) <= bw / 2)
  l[idx] <- 40 - 10 * log10(length(idx) * df)
  cat(sprintf("  bandwidth %7.2f Hz (%4d bins): %.4f sones\n",
              bw, length(idx), loud(f, l)))
}

cat("\n\nfinished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("log written to:", log_path, "\n")
sink()
