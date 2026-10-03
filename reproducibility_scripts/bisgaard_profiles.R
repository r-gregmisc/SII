## bisgaard_profiles.R ------------------------------------------------------------
## The 10 standard audiograms of Bisgaard, Vlaming & Dahlquist (2010), "Standard
## audiograms for the IEC 60118-15 measurement procedure", Trends in
## Amplification 14(2), 113-120: Table 2 (N1-N7, flat and moderately sloping)
## and Table 4 (S1-S3, steep sloping). Values checked against the published
## tables (pp. 116-117).
##
## Octave frequencies 250-4000 Hz are taken directly from the tables. The tables
## stop at 6000 Hz; the 8000 Hz threshold is set equal to the 6000 Hz value (cf.
## Johnson & Dillon, 2011, who set thresholds above 8000 Hz equal to 8000 Hz).
## All losses are sensorineural (air-bone gap 0).
##
## NAL-NL2 targets: real-ear insertion gain (dB) on the 19-point third-octave
## grid `bisgaard_freq19`, for speech at 50, 65 and 80 dB SPL, exported from the
## NAL-NL2 software (2026-09-29) with exactly these six thresholds entered in
## dB HL (inter-octave frequencies left blank), same audiogram both ears.
## Settings: adult, male, experienced, bilateral, non-tonal language,
## dual/adaptive compression speed, 18 channels, default compression threshold,
## supra-aural headphones as the threshold transducer (the reference assumed by
## the AUDMOD loudness model), occluded earmold with #13 tubing. Software: NAL-NL2 v2.0 (dll v2.15), Clinician Edition.
## Each export was checked on import: entered audiogram equal to the values
## below, left and right ears identical, no two profiles with identical gains.
## ---------------------------------------------------------------------------------

bisgaard_freq19 <- c(125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250,
                     1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000)

bisgaard_profiles <- list(
  ##                                   250  500 1000 2000 4000 8000(=6000)
  N1 = list(category = "Very mild",           threshold = c(10,  10,  10,  15,  30,  40),
            nalnl2_50 = c(0, 0, 0, 0, 0, 0, 0, 0, 0.1, 1.39, 2.36, 3.73, 5.29, 7.66, 10.75, 13.87, 13.87, 13.81, 13.42),
            nalnl2_65 = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.46, 1.01, 2.93, 5.43, 8.41, 8.7, 8.98, 9),
            nalnl2_80 = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.59, 1.13, 1.75, 2.21)),
  N2 = list(category = "Mild",                threshold = c(20,  20,  25,  35,  45,  50),
            nalnl2_50 = c(1.83, 1.83, 1.83, 1.83, 2.03, 2.3, 2.62, 4.77, 7.58, 10.89, 12.5, 14.77, 17.36, 18.74, 20.54, 23.13, 23.18, 23.18, 22.9),
            nalnl2_65 = c(0, 0, 0, 0, 0, 0, 0, 0.57, 3.24, 6.38, 7.44, 8.92, 10.62, 11.81, 13.35, 16.04, 16.43, 16.86, 17.06),
            nalnl2_80 = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.49, 1.26, 2.14, 2.83, 3.73, 5.94, 6.63, 7.44, 8.11)),
  N3 = list(category = "Moderate",            threshold = c(35,  35,  40,  50,  60,  65),
            nalnl2_50 = c(10.49, 10.49, 10.49, 10.49, 10.59, 10.72, 10.88, 13.31, 16.5, 20.24, 21.74, 23.85, 26.25, 27.33, 28.74, 31.26, 31.4, 31.5, 31.29),
            nalnl2_65 = c(2.26, 2.26, 2.26, 2.26, 2.43, 2.66, 2.92, 5.48, 8.82, 12.76, 14.03, 15.8, 17.83, 19.06, 20.66, 23.47, 23.92, 24.41, 24.64),
            nalnl2_80 = c(0, 0, 0, 0, 0, 0, 0, 0, 1.25, 3.42, 4.35, 5.66, 7.15, 8.13, 9.39, 11.93, 12.69, 13.58, 14.3)),
  N4 = list(category = "Moderate/severe",     threshold = c(55,  55,  55,  65,  75,  80),
            nalnl2_50 = c(21.1, 21.1, 21.1, 21.1, 21.74, 22.59, 23.58, 25.84, 28.78, 32.24, 33.44, 35.12, 37.04, 37.6, 38.32, 40.44, 40.57, 40.67, 40.45),
            nalnl2_65 = c(14.02, 14.02, 14.02, 14.02, 14.14, 14.3, 14.49, 16.64, 19.44, 22.74, 23.99, 25.73, 27.73, 28.79, 30.16, 32.68, 33.17, 33.71, 33.99),
            nalnl2_80 = c(2.79, 2.79, 2.79, 2.79, 3.04, 3.36, 3.74, 5.62, 8.07, 10.96, 12.13, 13.76, 15.63, 16.83, 18.4, 20.87, 21.71, 22.7, 23.49)),
  N5 = list(category = "Severe",              threshold = c(65,  70,  75,  80,  80,  80),
            nalnl2_50 = c(30.24, 30.24, 30.24, 30.24, 31.49, 33.13, 35.06, 37.05, 39.64, 42.69, 43.33, 44.24, 45.27, 44.83, 44.25, 45.35, 45.64, 45.96, 46.08),
            nalnl2_65 = c(23.81, 23.81, 23.81, 23.81, 24.33, 25.02, 25.82, 27.63, 30, 32.79, 33.8, 35.23, 36.85, 36.82, 36.78, 37.89, 38.54, 39.32, 40),
            nalnl2_80 = c(13.31, 13.31, 13.31, 13.31, 13.69, 14.18, 14.75, 16.31, 18.34, 20.74, 21.98, 23.72, 25.71, 25.9, 26.15, 27, 27.99, 29.2, 30.41)),
  N6 = list(category = "Severe",              threshold = c(75,  80,  85,  90, 100, 100),
            nalnl2_50 = c(35.51, 35.51, 35.51, 35.51, 37.06, 39.1, 41.5, 43.56, 46.25, 49.41, 50.23, 51.38, 52.69, 52.51, 52.26, 53.56, 53.73, 53.88, 53.78),
            nalnl2_65 = c(28.83, 28.83, 28.83, 28.83, 29.8, 31.07, 32.57, 34.6, 37.27, 40.4, 41.64, 43.39, 45.38, 45.73, 46.18, 47.46, 47.92, 48.44, 48.79),
            nalnl2_80 = c(19.28, 19.28, 19.28, 19.28, 20.03, 21.02, 22.18, 24.05, 26.51, 29.39, 30.93, 33.07, 35.52, 36.19, 37.33, 38.41, 39.17, 40.08, 40.91)),
  N7 = list(category = "Profound",            threshold = c(90,  95, 105, 105, 105, 105),
            nalnl2_50 = c(50.42, 50.42, 50.42, 50.42, 51.55, 53.03, 54.78, 55.56, 56.59, 57.81, 57.69, 57.53, 57.35, 56.67, 55.78, 56.73, 57.5, 58.43, 59.35),
            nalnl2_65 = c(44.3, 44.3, 44.3, 44.3, 44.87, 45.61, 46.49, 47.53, 48.89, 50.49, 50.82, 51.28, 51.81, 51.12, 50.22, 50.79, 51.65, 52.71, 53.78),
            nalnl2_80 = c(33.91, 33.91, 33.91, 33.91, 34.33, 34.88, 35.53, 37, 38.92, 41.17, 42.12, 43.44, 44.95, 42.59, 43.22, 43, 43.91, 45.02, 46.19)),
  S1 = list(category = "Very mild, steep",    threshold = c(10,  10,  10,  15,  55,  70),
            nalnl2_50 = c(0, 0, 0, 0, 0, 0, 0, 0, 1.39, 3.17, 4.16, 5.54, 7.13, 11.76, 17.79, 23.07, 23.12, 23.08, 22.5),
            nalnl2_65 = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0.95, 1.29, 1.77, 2.32, 6.33, 11.54, 16.75, 17.04, 17.28, 17.06),
            nalnl2_80 = c(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2.5, 7.04, 7.56, 8.13, 8.35)),
  S2 = list(category = "Mild, steep",         threshold = c(20,  20,  25,  55,  95,  95),
            nalnl2_50 = c(0.13, 0.13, 0.13, 0.13, 1.01, 2.16, 3.52, 6.66, 10.78, 15.62, 18.51, 22.55, 27.17, 27.84, 28.72, 29.25, 29.02, 28.67, 27.98),
            nalnl2_65 = c(0, 0, 0, 0, 0, 0, 0, 2.29, 6.21, 10.84, 13.5, 17.23, 21.49, 23.03, 25.02, 26.88, 26.86, 26.75, 26.29),
            nalnl2_80 = c(0, 0, 0, 0, 0, 0, 0, 0, 1.63, 4.04, 6, 8.73, 11.86, 13.98, 16.74, 19.57, 19.79, 19.97, 19.81)),
  S3 = list(category = "Moderate/severe, steep", threshold = c(30, 35, 60, 75, 80, 85),
            nalnl2_50 = c(12.12, 12.12, 12.12, 12.12, 13.01, 14.16, 15.53, 19.13, 23.85, 29.4, 31.81, 35.18, 39.04, 39.9, 41.02, 42.59, 42.45, 42.22, 41.68),
            nalnl2_65 = c(2.93, 2.93, 2.93, 2.93, 3.97, 5.33, 6.94, 10.63, 15.45, 21.12, 23.73, 27.37, 31.53, 32.78, 34.41, 36.05, 36.14, 36.2, 36.01),
            nalnl2_80 = c(0, 0, 0, 0, 0, 0, 0, 2.72, 6.45, 10.83, 13.3, 16.75, 20.69, 22.04, 23.8, 25.21, 25.57, 25.99, 26.26))
)

## NAL-NL2 gain (dB) at `target_freqs` for one profile and input level, or NULL
## if not yet entered.
get_bisgaard_nalnl2 <- function(profile, target_freqs, level = 65) {
  y <- bisgaard_profiles[[profile]][[paste0("nalnl2_", level)]]
  if (is.null(y)) return(NULL)
  stopifnot(length(y) == length(bisgaard_freq19))
  approx(log10(bisgaard_freq19), y, log10(target_freqs), rule = 2)$y
}
bisgaard_nal_ready <- function()
  all(vapply(bisgaard_profiles, function(p) length(p$nalnl2_65) == 19, logical(1)))
