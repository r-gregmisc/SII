library(testthat)

test_that("AUDMOD C++ port matches AMT 1.6.0 exactly", {
  cases <- read.csv("fixtures/audmod/in/cases_numeric.csv", header=FALSE)
  
  for (i in 1:nrow(cases)) {
    case_id <- cases[i, 1]
    
    # 13 loss, 13 ucl
    ag_loss <- as.numeric(cases[i, 2:14])
    ag_ucl <- as.numeric(cases[i, 15:27])
    
    # Run reference
    ref <- audmod_reference_cpp(fs = 32000, N = 8192, AGLoss_HL = ag_loss, AG_UCL_HL = ag_ucl)
    
    # Read spec
    spec_file <- sprintf("fixtures/audmod/in/spec_%d.csv", case_id)
    spec_in <- read.csv(spec_file, header=FALSE)[,1]
    
    # Run loudness
    res <- audmod_loudness_cpp(PowSpect_in = spec_in, fs = 32000, N = 8192, ref = ref)
    
    # Read expected
    out_file <- sprintf("fixtures/audmod/out/amt_%d.csv", case_id)
    expected <- read.csv(out_file)
    
    # Compare
    expect_equal(ref$E_0, expected$E_0, tolerance = 1e-10)
    expect_equal(ref$E_TQ, expected$E_TQ, tolerance = 1e-10)
    expect_equal(ref$E_UCL, expected$E_UCL, tolerance = 1e-10)
    expect_equal(res$E_SPL, expected$E_SPL, tolerance = 1e-10)
    expect_equal(res$E_Vector, expected$E_Vector, tolerance = 1e-10)
    expect_equal(res$HTLL, expected$HTLL, tolerance = 1e-10)
    expect_equal(res$N_prime, expected$N_prime, tolerance = 1e-10)
    expect_equal(res$Ldn, expected$Ldn[1], tolerance = 1e-10)
  }
})
