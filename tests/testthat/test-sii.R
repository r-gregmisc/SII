test_that("Open-NL S3 Prescription Target", {
  # Test that open_nl() returns a prescription_target object
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  thresh <- c(10, 10, 20, 30, 40, 50)
  
  target <- open_nl(speech = 65, threshold = thresh, freq = freqs)
  
  expect_s3_class(target, "prescription_target")
  expect_equal(length(target$gain), length(freqs))
  expect_equal(length(target$mpo), length(freqs))
})
