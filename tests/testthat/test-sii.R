test_that("ANSI S3.5-1997 Annex B - Normal Hearing Validation", {
  ansib <- read.table(system.file("extdata", "ANSI.B.txt", package="SII"), header=TRUE)
  
  result <- sii(
    speech = ansib$E.,
    noise = ansib$N.,
    threshold = ansib$T.,
    method = "critical"
  )
  
  expect_equal(round(result$sii, 3), 0.504, tolerance = 0.001)
})

test_that("ANSI S3.5-1997 Annex C - Impaired Hearing Validation", {
  ansic <- read.table(system.file("extdata", "ANSI.C.txt", package="SII"), header=TRUE)
  
  result <- sii(
    speech = ansic$E.,
    noise = ansic$N.,
    threshold = ansic$T.,
    method = "critical"
  )
  
  expect_equal(round(result$sii, 3), 0.443, tolerance = 0.001)
})

test_that("Open-NL S3 Prescription Target", {
  # Test that open_nl() returns a prescription_target object
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  thresh <- c(10, 10, 20, 30, 40, 50)
  
  target <- open_nl(speech = 65, threshold = thresh, freq = freqs)
  
  expect_s3_class(target, "prescription_target")
  expect_equal(length(target$gain), length(freqs))
  expect_equal(length(target$mpo), length(freqs))
})
