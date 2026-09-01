library(SII)
Rcpp::sourceCpp("src/bramslow2004.cpp")
source("R/benchmark_targets.R")
source("R/nalr.R")
source("R/open_nl.R")

out_file <- "table6_output.txt"
cat("| Profile | Formula | ANSI SII | Desensitized SII |\n", file=out_file)
cat("|---|---|---|---|\n", file=out_file, append=TRUE)

profiles <- c("a1", "a2", "a3", "a4", "a5", "a6", "a7")
profile_names <- c("A1", "A2", "A3", "A4", "A5", "A6", "A7")

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
    
    data("critical", package="SII", envir = environment())
    normal_speech <- approx(x = log10(critical$fi), y = critical$normal, xout = log10(freqs), rule = 2)$y
    overall_normal <- 10 * log10(sum((10^(critical$normal / 10)) * (critical$hi - critical$li), na.rm = TRUE))
    speech_spec <- normal_speech + (65 - overall_normal)

    nalnl2_tgt <- get_jd2011_target(p, "NAL-NL2", freqs, 65)
    obj_nalnl2 <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=nalnl2_tgt, desensitization=TRUE)
    
    opennl_tgt <- open_nl(speech=65, threshold=threshold, freq=freqs, loss=loss, optimize=TRUE, enable_severe_booster=TRUE, booster_onset=60)
    obj_opennl <- sii(speech=speech_spec, threshold=threshold, loss=loss, freq=freqs, method="octave", transducer="none", custom_gain=opennl_tgt$gain, desensitization=TRUE)
    
    cat(sprintf("| %s | NAL-NL2 | %.2f | %.2f |\n", p_name, obj_nalnl2$sii, obj_nalnl2$desensitized_sii), file=out_file, append=TRUE)
    cat(sprintf("| %s | Open-NL | %.2f | %.2f |\n", p_name, obj_opennl$sii, obj_opennl$desensitized_sii), file=out_file, append=TRUE)
  }, error = function(e) {
    cat(sprintf("ERROR on profile %s: %s\n", p_name, e$message), file=out_file, append=TRUE)
  })
}
cat("\nSUCCESS!\n", file=out_file, append=TRUE)
