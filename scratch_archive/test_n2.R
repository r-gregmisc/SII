library(SII)
source("R/sii.R")
source("R/nalr.R")
source("R/open_nl.R")

htl <- c(20, 30, 45, 60, 75, 80)
cond <- rep(0, 6)
freqs <- c(250, 500, 1000, 2000, 4000, 8000)

cat("\n--- RUNNING OPEN-NL OPTIMIZER FOR N2 ---\n")
opennl_res <- open_nl(speech=65, threshold=htl, loss=cond, freq=freqs, config="bilateral")
target_opennl_6 <- opennl_res$gain
speech_spec <- opennl_res$speech
cat("Optimized Gain:", round(target_opennl_6, 2), "\n")

sii_obj <- sii(speech=speech_spec, threshold=htl, loss=cond, freq=freqs, method="octave", transducer="none", custom_gain=target_opennl_6, desensitization=FALSE)
val <- calculate_loudness(sii_obj)$total
cat("Shiny SII.R LOUDNESS FOR TARGET:", val, "\n")
