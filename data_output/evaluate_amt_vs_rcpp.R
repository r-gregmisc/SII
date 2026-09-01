# evaluate_amt_vs_rcpp.R
# Compares 65 dB SPL Sone levels for NAL-NL2 and Open-NL 
# against the AMT (bramslow2004) gold standard

devtools::load_all(".")
load("data/critical.rda")

amt_matlab <- c(4.15, 6.02, 3.51, 4.47, 3.65, 6.45, 6.56, 6.22, 5.52, 6.34, 2.10, 3.72, 3.09, 3.21)
labels <- c("A1 NAL", "A1 Open", "A2 NAL", "A2 Open", "A3 NAL", "A3 Open", "A4 NAL", "A4 Open", "A5 NAL", "A5 Open", "A6 NAL", "A6 Open", "A7 NAL", "A7 Open")
presets <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")

cpp_rcpp <- numeric(14)
f_21 <- critical$fi
overall_normal <- 62.35 

test_audiograms <- list(
  "a1" = list(htl = c(15, 20, 30, 40, 50, 60), bc = NULL),
  "a2" = list(htl = c(60, 50, 40, 30, 20, 15), bc = NULL),
  "a3" = list(htl = c(10, 20, 40, 50, 55, 60), bc = NULL),
  "a4" = list(htl = c(0, 0, 10, 40, 70, 80), bc = NULL),
  "a5" = list(htl = c(10, 10, 20, 60, 80, 100), bc = NULL),
  "a6" = list(htl = c(50, 55, 60, 65, 75, 80), bc = c(20, 25, 30, 35, 45)),
  "a7" = list(htl = c(50, 50, 50, 50, 50, 50), bc = c(10, 10, 10, 10, 10))
)

hl_freqs <- c(250, 500, 1000, 2000, 4000, 8000)
bc_freqs <- c(250, 500, 1000, 2000, 4000)
speech_input <- critical$normal + (65 - overall_normal)

for (i in 1:7) {
  p <- presets[i]
  profile <- test_audiograms[[p]]
  
  htl_21 <- approx(x = log10(hl_freqs), y = profile$htl, xout = log10(f_21), rule = 2)$y
  if (!is.null(profile$bc)) {
    bc_21 <- approx(x = log10(bc_freqs), y = profile$bc, xout = log10(f_21), rule = 2)$y
    loss_21 <- pmax(0, htl_21 - bc_21)
  } else {
    loss_21 <- rep(0, length(htl_21))
  }
  
  # NAL-NL2 Sones
  nal_tgt <- get_nalnl2_v2_target(p, "NAL-NL2", f_21, 65)
  obj_nal <- sii(speech = speech_input, threshold = htl_21, loss = loss_21, freq = f_21, 
                 custom_gain = nal_tgt)
  cpp_rcpp[(i-1)*2 + 1] <- calculate_loudness(obj_nal)$total
  
  # Open-NL Sones
  obj_open <- sii(speech = speech_input, threshold = htl_21, loss = loss_21, freq = f_21, 
                  prescription = "Open-NL")
  cpp_rcpp[(i-1)*2 + 2] <- calculate_loudness(obj_open)$total
}

errors <- abs(amt_matlab - cpp_rcpp)
mae <- mean(errors)

cat(sprintf("Overall MAE vs AMT Gold Standard: %.3f sones\n\n", mae))
cat(sprintf("%-10s | %-12s | %-12s | %-8s\n", "Profile", "AMT (MATLAB)", "RCPP (R)", "Error"))
cat("------------------------------------------------------\n")
for (i in 1:length(labels)) {
  cat(sprintf("%-10s | %-12.2f | %-12.2f | %-8.2f\n", labels[i], amt_matlab[i], cpp_rcpp[i], errors[i]))
}
