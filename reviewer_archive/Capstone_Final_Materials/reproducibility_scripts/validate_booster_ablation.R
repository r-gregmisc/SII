devtools::load_all(".", quiet=TRUE)
source("R/benchmark_targets.R")
options(mc.cores = 1)
input_speech <- c(37.4, 36.92, 27.66, 19.97, 11.98, 3.78)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)

for (p in c("a4", "a5")) {
  target_data <- jd2011_targets[[p]]
  threshold <- target_data$threshold
  loss <- rep(0, 6)
  
  opennl_con <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=FALSE)
  
  obj_opennl_raw_con <- sii(speech=input_speech, noise=rep(-50,6), threshold=threshold, loss=loss, freq=freqs, prescription=opennl_con, method="octave", transducer="none", desensitization=FALSE)
  obj_opennl_des_con <- sii(speech=input_speech, noise=rep(-50,6), threshold=threshold, loss=loss, freq=freqs, prescription=opennl_con, method="octave", transducer="none", desensitization=TRUE)
  opennl_sones_con <- calculate_loudness(opennl_con)$total
  
  cat(sprintf("| %s | Open-NL (Conservative) | %.2f | %.2f | %.2f |\n", p, obj_opennl_raw_con$sii, obj_opennl_des_con$sii, opennl_sones_con))
  cat(sprintf("| %s | Open-NL (Conservative) Gains | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f |\n", p, opennl_con$gain[1], opennl_con$gain[2], opennl_con$gain[3], opennl_con$gain[4], opennl_con$gain[5], opennl_con$gain[6]))
}
