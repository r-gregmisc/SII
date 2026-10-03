devtools::load_all(".", quiet=TRUE)
source("R/benchmark_targets.R")
Rcpp::sourceCpp("src/bramslow2004.cpp")

calc_amt_loudness <- function(gain_tgt, htl, cond, target_level) {
  obj <- list(gain=gain_tgt, freq=c(250,500,1000,2000,4000,8000), threshold=htl, loss=cond, vocal_effort=paste(target_level, "dB SPL"))
  return(SII:::calculate_loudness(obj)$total)
}

cat("Ablation of SD-LFP Heuristic Constraints on Optimizer Seed (65 dB SPL Input)\n")
cat("Generated using the aggressive 60 dB HL booster onset.\n")
cat(sprintf("%-15s | %-22s | %-24s | %-15s | %-17s\n", 
    "Profile", "Unconstrained Seed SII", "Unconstrained Seed Sones", "SD-LFP Seed SII", "SD-LFP Seed Sones"))
cat(paste(rep("-", 103), collapse=""), "\n")

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1 (Mild/Mod)", "A2 (Reverse)", "A3 (Gentle)", "A4 (Steep)", 
                   "A5 (Profound)", "A6 (Mixed)", "A7 (Conductive)")

for (i in seq_along(profiles)) {
  p <- profiles[i]
  p_name <- profile_names[i]
  target_data <- jd2011_targets[[p]]
  freqs <- c(250, 500, 1000, 2000, 4000, 8000)
  threshold <- target_data$threshold
  
  loss <- rep(0, 6)
  if (p == "a6") loss <- rep(30, 6)
  if (p == "a7") loss <- rep(50, 6)
  
  presc_uncon <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss, 
                         optimize = FALSE, disable_sdlfp = TRUE, 
                         enable_severe_booster = TRUE, booster_onset = 60)
  
  obj_uncon <- sii(speech = c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold = threshold, loss = loss, freq = freqs, 
                   prescription = presc_uncon, method = "octave", 
                   desensitization = FALSE, transducer = "none")
  
  sii_uncon <- obj_uncon$sii
  sones_uncon <- calc_amt_loudness(presc_uncon$gain, threshold, loss, 65)
  
  presc_con <- open_nl(speech = 65, threshold = threshold, freq = freqs, loss = loss, 
                       optimize = FALSE, disable_sdlfp = FALSE, 
                       enable_severe_booster = TRUE, booster_onset = 60)
  
  obj_con <- sii(speech = c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78), threshold = threshold, loss = loss, freq = freqs, 
                 prescription = presc_con, method = "octave", 
                 desensitization = FALSE, transducer = "none")
  
  sii_con <- obj_con$sii
  sones_con <- calc_amt_loudness(presc_con$gain, threshold, loss, 65)
  
  cat(sprintf("%-15s | %22.2f | %24.1f | %15.2f | %17.1f\n", 
              p_name, sii_uncon, sones_uncon, sii_con, sones_con))
}
