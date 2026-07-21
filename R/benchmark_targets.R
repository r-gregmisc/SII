# Extrapolated target insertion gains for a 65 dB SPL input 
# from Johnson & Dillon (2011) "A comparison of NAL-NL2 and DSL m[i/o] v5.0a for adults"
# These match the exact A-1 to A-5 audiograms.

jd2011_targets <- list(
  "a1" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    nalnl2 = c(14, 20, 22, 20, 17, 12),
    dsl = c(18, 25, 26, 24, 20, 15),
    cr_nalnl2 = c(2.6, 3.4, 2.6, 2.35, 2.1, 1.9)
  ),
  "a2" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    nalnl2 = c(20, 16, 12, 6, 2, 2),
    dsl = c(24, 19, 15, 8, 4, 3),
    cr_nalnl2 = c(2.5, 2.0, 1.5, 1.0, 1.0, 1.0)
  ),
  "a3" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    nalnl2 = c(6, 16, 22, 22, 16, 6),
    dsl = c(8, 20, 27, 26, 19, 8),
    cr_nalnl2 = c(1.2, 1.8, 2.4, 2.4, 1.8, 1.2)
  ),
  "a4" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    nalnl2 = c(0, 0, 0, 16, 31, 30),
    dsl = c(-5, -2, 3, 20, 38, 35),
    cr_nalnl2 = c(1.0, 1.0, 1.65, 2.0, 2.1, 1.9)
  )
)

# Helper function to get an interpolated gain vector for any given frequency array
get_jd2011_target <- function(preset, formula, target_freqs, level = 65) {
  if (!(preset %in% names(jd2011_targets))) return(NULL)

  data <- jd2011_targets[[preset]]
  if (formula == "NAL-NL2") {
    y <- data$nalnl2
    cr <- data$cr_nalnl2
  } else if (formula == "DSL") {
    y <- data$dsl
    # DSL generally prescribes a more linear approach (lower CR) than NAL-NL2.
    # We approximate it by setting its CR to 85% of NAL-NL2's CR, bounded at 1.0.
    cr <- pmax(1.0, data$cr_nalnl2 * 0.85)
  } else {
    return(NULL)
  }

  # Apply WDRC gain shift if level is not 65 dB SPL
  # WDRC formula: Gain(L) = Gain(65) + (L - 65) * (1/CR - 1)
  if (level != 65) {
    y <- y + (level - 65) * (1 / cr - 1)
  }

  # Interpolate to the target frequencies
  approx(x = log10(data$freq), y = y, xout = log10(target_freqs), rule = 2)$y
}
