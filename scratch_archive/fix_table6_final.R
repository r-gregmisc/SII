library(SII)
source("R/benchmark_targets.R")

opennl_gains <- list(
  a1 = c(0.0, 7.2, 15.8, 18.4, 22.0, 12.8),
  a2 = c(11.8, 18.0, 20.4, 13.8, 8.2, 2.5),
  a3 = c(0.0, 7.2, 20.4, 23.0, 24.3, 12.8),
  a4 = c(0.0, 0.0, 6.6, 18.4, 32.7, 18.9),
  a5 = c(0.0, 0.0, 11.2, 27.6, 38.8, 23.5),
  a6 = c(16.3, 29.0, 38.3, 38.6, 42.2, 33.0),
  a7 = c(24.9, 32.5, 39.5, 37.5, 36.5, 36.5)
)

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

cat("| Profile | Formula | ANSI SII | Desensitized SII |\n")
cat("|---|---|---|---|\n")

for (i in seq_along(profiles)) {
  tryCatch({
    p <- profiles[i]
    p_name <- profile_names[i]
    target_data <- jd2011_targets[[p]]
    freqs <- target_data$freq
    threshold <- target_data$threshold
    loss <- rep(0, 6)
    if (p == "a6") loss <- rep(30, 6)
    if (p == "a7") loss <- rep(50, 6)
    
    critical <- read.csv("data-raw/critical.csv") # Assuming this exists or data("critical")
    normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
    overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
    speech_spec <- normal_speech + (65 - overall_normal)

    nalnl2_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
    obj_nalnl2 <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nalnl2_tgt, desensitization=TRUE)
    
    op_gain <- opennl_gains[[p]]
    obj_opennl <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=op_gain, desensitization=TRUE)
    
    cat(sprintf("| %s | NAL-NL2 | %.2f | %.2f |\n", p_name, obj_nalnl2$sii, obj_nalnl2$desensitized_sii))
    cat(sprintf("| %s | Open-NL | %.2f | %.2f |\n", p_name, obj_opennl$sii, obj_opennl$desensitized_sii))
  }, error = function(e) {
    cat(sprintf("ERROR on %s: %s\n", profile_names[i], e$message))
  })
}
cat("\nSUCCESS!\n")
