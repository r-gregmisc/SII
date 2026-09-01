library(SII)

htl_A1 <- c(10, 10, 10, 10, 10, 10)
f_htl <- c(250, 500, 1000, 2000, 4000, 8000)
loss <- rep(0, 6)

# Test native open_nl call with the manuscript parameters!
presc <- open_nl(speech = 65, threshold = htl_A1, freq = f_htl, loss = loss, optimize = TRUE, enable_severe_booster = TRUE, booster_onset = 60)

obj <- sii(speech = presc$speech, threshold = presc$threshold, loss = presc$loss, 
           freq = presc$freq, prescription = presc, method = "octave",
           desensitization = FALSE, transducer = "none")

cat("A1 Sones with booster ON and onset 60 (Manuscript):", obj$loudness_monaural, "\n")

# Test native open_nl call with the USER'S requested parameters!
presc_off <- open_nl(speech = 65, threshold = htl_A1, freq = f_htl, loss = loss, optimize = TRUE, enable_severe_booster = FALSE, booster_onset = 70)

obj_off <- sii(speech = presc_off$speech, threshold = presc_off$threshold, loss = presc_off$loss, 
           freq = presc_off$freq, prescription = presc_off, method = "octave",
           desensitization = FALSE, transducer = "none")

cat("A1 Sones with booster OFF and onset 70 (User request):", obj_off$loudness_monaural, "\n")
