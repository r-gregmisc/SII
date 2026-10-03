library(testthat)

test_that("normal_speech_loudness computes correctly", {
  val_50 <- normal_speech_loudness(50)
  val_65 <- normal_speech_loudness(65)
  val_80 <- normal_speech_loudness(80)
  
  expect_equal(val_50, 3.1577, tolerance = 0.01)
  expect_equal(val_65, 9.0333, tolerance = 0.01)
  expect_equal(val_80, 22.3887, tolerance = 0.01)
})

test_that("legacy cap rule holds loudness at its cap", {
  thr <- c(0, 0, 10, 40, 70, 80)
  frq <- c(250, 500, 1000, 2000, 4000, 8000)
  # Legacy cap at 65 dB SPL for a PTA (0.5-4 kHz) of 30 dB HL: about 4.8 sones,
  # below the ~8.5 sones of the unoptimized gains, so it binds.
  legacy_cap <- approx(c(10, 32.5, 52.5, 72.5, 90), c(7.0, 4.5, 4.0, 6.5, 6.0),
                       xout = mean(c(0, 10, 40, 70)))$y
  res_legacy <- open_nl(speech = 65, threshold = thr, freq = frq, cap_rule = "legacy")
  res_normal <- open_nl(speech = 65, threshold = thr, freq = frq, cap_rule = "normal")
  loud_legacy <- calculate_loudness(res_legacy)$total
  expect_lte(loud_legacy, legacy_cap + 0.1)
  expect_lt(loud_legacy, calculate_loudness(res_normal)$total)
})

test_that("cap_override overrides cap_rule", {
  res_legacy <- open_nl(speech = 65, threshold = c(0,0,10,40,70,80), freq = c(250, 500, 1000, 2000, 4000, 8000), cap_rule = "legacy", cap_override = 100)
  res_normal <- open_nl(speech = 65, threshold = c(0,0,10,40,70,80), freq = c(250, 500, 1000, 2000, 4000, 8000), cap_rule = "normal", cap_override = 100)
  
  expect_equal(res_legacy$gain, res_normal$gain)
})

test_that("open_nl() optimizes when loss is not supplied, and the cap binds", {
  op <- options(open_nl_starts = 1, open_nl_maxit = 200)
  on.exit(options(op))
  thr <- c(0, 0, 10, 40, 70, 80)
  frq <- c(250, 500, 1000, 2000, 4000, 8000)
  loose <- open_nl(speech = 65, threshold = thr, freq = frq, cap_override = 100)
  tight <- open_nl(speech = 65, threshold = thr, freq = frq, cap_override = 0.5)
  # A binding cap must lower the prescribed gain
  expect_lt(sum(tight$gain), sum(loose$gain))
  # Omitting loss must give the same result as loss = 0
  zero <- open_nl(speech = 65, threshold = thr, freq = frq, cap_override = 0.5,
                  loss = rep(0, 6))
  expect_equal(tight$gain, zero$gain)
})
