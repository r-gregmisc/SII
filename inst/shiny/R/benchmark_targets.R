# Extrapolated target insertion gains for a 65 dB SPL input 
# from Johnson & Dillon (2011) "A comparison of NAL-NL2 and DSL m[i/o] v5.0a for adults"
# These match the exact A-1 to A-7 audiograms.

jd2011_targets <- list(
  "a1" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    threshold = c(15, 20, 30, 40, 50, 60),
    nalnl2 = c(14, 20, 22, 20, 17, 12),
    dsl = c(18, 25, 26, 24, 20, 15),
    cameq2 = c(20, 19, 25, 27, 28, 38),
    cr_nalnl2 = c(2.6, 3.4, 2.6, 2.35, 2.1, 1.9)
  ),
  "a2" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    threshold = c(60, 50, 40, 30, 20, 15),
    nalnl2 = c(20, 16, 12, 6, 2, 2),
    dsl = c(24, 19, 15, 8, 4, 3),
    cameq2 = c(28, 28, 28, 20, 0, 0),
    cr_nalnl2 = c(2.5, 2.0, 1.5, 1.0, 1.0, 1.0)
  ),
  "a3" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    threshold = c(10, 20, 40, 50, 55, 60),
    nalnl2 = c(6, 16, 22, 22, 16, 6),
    dsl = c(8, 20, 27, 26, 19, 8),
    cameq2 = c(12, 12, 24, 28, 27, 40),
    cr_nalnl2 = c(1.2, 1.8, 2.4, 2.4, 1.8, 1.2)
  ),
  "a4" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    threshold = c(0, 0, 10, 40, 70, 80),
    nalnl2 = c(0, 0, 0, 16, 31, 30),
    dsl = c(0, 0, 3, 20, 38, 35),
    cameq2 = c(10, 10, 15, 25, 30, 60),
    cr_nalnl2 = c(1.0, 1.0, 1.65, 2.0, 2.1, 1.9)
  ),
  "a5" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    threshold = c(10, 10, 20, 60, 80, 100),
    nalnl2 = c(0, 0, 15, 28, 30, 30),
    dsl = c(0, 0, 15, 30, 25, 25),
    cameq2 = c(10, 10, 25, 45, 60, 65),
    cr_nalnl2 = c(1.0, 1.0, 2.0, 2.5, 2.1, 1.9)
  ),
  "a6" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    threshold = c(50, 55, 60, 65, 75, 80),
    loss = c(30, 30, 30, 30, 30, 30),
    nalnl2 = c(30, 32, 40, 42, 45, 45),
    dsl = c(32, 35, 43, 35, 35, 38),
    cameq2 = c(48, 48, 52, 43, 48, 52),
    cr_nalnl2 = c(2.0, 2.2, 2.5, 2.5, 2.1, 1.9)
  ),
  "a7" = list(
    freq = c(250, 500, 1000, 2000, 4000, 8000),
    threshold = c(50, 50, 50, 50, 50, 50),
    loss = c(50, 50, 50, 50, 50, 50),
    nalnl2 = c(14, 15, 17, 18, 18, 18),
    dsl = c(30, 30, 37, 34, 32, 31),
    cameq2 = c(40, 40, 45, 43, 40, 40),
    cr_nalnl2 = c(1.0, 1.0, 1.0, 1.0, 1.0, 1.0)
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
    cr <- pmax(1.0, data$cr_nalnl2 * 0.85)
  } else if (formula == "CAMEQ2-HF") {
    y <- data$cameq2
    cr <- pmax(1.0, data$cr_nalnl2 * 0.90)
  } else {
    return(NULL)
  }

  # Apply WDRC gain shift if level is not 65 dB SPL
  if (level != 65) {
    y <- y + (level - 65) * (1 / cr - 1)
  }

  # Interpolate to the target frequencies
  approx(x = log10(data$freq), y = y, xout = log10(target_freqs), rule = 2)$y
}
