#!/usr/bin/env Rscript
# Unit tests for desensitization_scale parameter
# Tests:
#   1. scale=0 reproduces raw ANSI SII exactly
#   2. scale=1 reproduces current (full desensitization) output exactly
#   3. For a fixed gain vector, scores at 0, 0.5, 1 are collinear

pkg_root <- "/home/mark/Development/SII-github"
devtools::load_all(pkg_root, reset = TRUE, quiet=TRUE)
source(file.path(pkg_root, "R/sii.R"), local = FALSE)
load(file.path(pkg_root, "data/critical.rda"))

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
pass <- TRUE

for (p in c("a4", "a5", "a6", "a7")) {
  target_data <- jd2011_targets[[p]]
  htl <- target_data$threshold
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)

  normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(hl_freqs), rule = 2)$y
  overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
  speech_spec <- normal_speech + (65 - overall_normal)

  # Use a fixed gain vector (simple half-gain rule)
  gain <- pmax(0, htl * 0.46 + 2)

  # Test 1: scale=0 should equal desensitization="none"
  sii_raw <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                 method = "octave", transducer = "none", custom_gain = gain,
                 desensitization = "none")$sii

  sii_scale0 <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                    method = "octave", transducer = "none", custom_gain = gain,
                    desensitization = "johnson2011_complete", desensitization_scale = 0.0)$sii

  if (abs(sii_raw - sii_scale0) > 1e-10) {
    cat(sprintf("FAIL [%s]: scale=0 (%.6f) != raw (%.6f), diff=%.2e\n", p, sii_scale0, sii_raw, abs(sii_raw - sii_scale0)))
    pass <- FALSE
  } else {
    cat(sprintf("PASS [%s]: scale=0 matches raw ANSI SII (%.6f)\n", p, sii_raw))
  }

  # Test 2: scale=1 should equal full desensitization
  sii_full <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                  method = "octave", transducer = "none", custom_gain = gain,
                  desensitization = "johnson2011_complete", desensitization_scale = 1.0)$sii

  sii_full_old <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                      method = "octave", transducer = "none", custom_gain = gain,
                      desensitization = "johnson2011_complete")$sii

  if (abs(sii_full - sii_full_old) > 1e-10) {
    cat(sprintf("FAIL [%s]: scale=1 (%.6f) != full desens (%.6f)\n", p, sii_full, sii_full_old))
    pass <- FALSE
  } else {
    cat(sprintf("PASS [%s]: scale=1 matches full desensitization (%.6f)\n", p, sii_full))
  }

  # Test 3: Collinearity at 0, 0.5, 1 for a fixed gain vector
  sii_half <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                  method = "octave", transducer = "none", custom_gain = gain,
                  desensitization = "johnson2011_complete", desensitization_scale = 0.5)$sii

  expected_half <- (sii_raw + sii_full) / 2
  if (abs(sii_half - expected_half) > 1e-10) {
    cat(sprintf("FAIL [%s]: scale=0.5 (%.6f) != midpoint (%.6f), diff=%.2e\n", p, sii_half, expected_half, abs(sii_half - expected_half)))
    pass <- FALSE
  } else {
    cat(sprintf("PASS [%s]: scale=0.5 is collinear (%.6f == midpoint %.6f)\n", p, sii_half, expected_half))
  }
}

if (pass) {
  cat("\nAll tests PASSED.\n")
} else {
  cat("\nSome tests FAILED.\n")
  quit(status = 1)
}
