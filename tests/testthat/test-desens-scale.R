test_that("desensitization_scale works correctly", {
  data("critical", package="SII", envir=environment())
  hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)

  for (p in c("a4", "a5", "a6", "a7")) {
    target_data <- SII:::jd2011_targets[[p]]
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

    expect_equal(sii_scale0, sii_raw, tolerance = 1e-10)

    # Test 2: scale=1 should equal full desensitization
    sii_full <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                    method = "octave", transducer = "none", custom_gain = gain,
                    desensitization = "johnson2011_complete", desensitization_scale = 1.0)$sii

    sii_full_old <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                        method = "octave", transducer = "none", custom_gain = gain,
                        desensitization = "johnson2011_complete")$sii

    expect_equal(sii_full, sii_full_old, tolerance = 1e-10)

    # Test 3: Collinearity at 0, 0.5, 1 for a fixed gain vector
    sii_half <- sii(speech = speech_spec, threshold = htl, loss = loss, freq = hl_freqs,
                    method = "octave", transducer = "none", custom_gain = gain,
                    desensitization = "johnson2011_complete", desensitization_scale = 0.5)$sii

    expected_half <- (sii_raw + sii_full) / 2
    expect_equal(sii_half, expected_half, tolerance = 1e-10)
  }
})
