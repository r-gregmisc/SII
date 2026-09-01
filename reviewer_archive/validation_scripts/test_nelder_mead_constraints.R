#!/usr/bin/env Rscript

# Helper function to create open_nl_test script to test the refactored code.

cat("Loading Open-NL test script...\n")
source("R/open_nl.R")
source("R/sii.R")
source("R/nalr.R")
source("R/moore_glasberg.R")

test_profile <- function(prof_name, threshold, loss) {
  cat(sprintf("\n=== Testing %s ===\n", prof_name))
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  
  # Interpolate to 21 bands
  data(critical)
  f_21 <- critical$fi
  htl_21 <- approx(log10(freqs), threshold, log10(f_21), rule=2)$y
  loss_21 <- approx(log10(freqs), loss, log10(f_21), rule=2)$y
  
  cat("Running 65 dB SPL...\n")
  t65 <- open_nl(speech = 65, threshold = htl_21, freq = f_21, loss = loss_21)
  
  cat("Running 50 dB SPL...\n")
  t50 <- open_nl(speech = 50, threshold = htl_21, freq = f_21, loss = loss_21)
  
  cat("Running 80 dB SPL...\n")
  t80 <- open_nl(speech = 80, threshold = htl_21, freq = f_21, loss = loss_21)
  
  # Calculate CR at octave bands
  g50 <- approx(log10(f_21), t50$gain, log10(freqs), rule=2)$y
  g65 <- approx(log10(f_21), t65$gain, log10(freqs), rule=2)$y
  g80 <- approx(log10(f_21), t80$gain, log10(freqs), rule=2)$y
  
  cr_50_80 <- 30 / ((80 + g80) - (50 + g50))
  
  df <- data.frame(Freq=freqs, G50=round(g50, 1), G65=round(g65, 1), G80=round(g80, 1), CR50_80=round(cr_50_80, 2))
  print(df)
}

# A1 Profile
test_profile("A1 (Mild SN)", c(15, 20, 30, 40, 50, 60), c(0, 0, 0, 0, 0, 0))

# A7 Profile (Bisgaard N7 - Severe SN)
test_profile("A7 (Severe SN)", c(50, 50, 60, 70, 80, 90), c(0, 0, 0, 0, 0, 0))

# Pure Conductive Profile (Custom)
test_profile("Pure Conductive (40 dB)", c(40, 40, 40, 40, 40, 40), c(40, 40, 40, 40, 40, 40))
