library(SII)

htl_A1 <- c(10, 10, 10, 10, 10, 10)
f_htl <- c(250, 500, 1000, 2000, 4000, 8000)
loss <- rep(0, 6)

presc <- open_nl(speech = 65, threshold = htl_A1, freq = f_htl, loss = loss, config = "bilateral", optimize = TRUE)

cat("Open-NL Target Gains for A1:\n")
print(presc$gain)

obj <- sii(speech = 65, threshold = htl_A1, loss = loss, 
           freq = f_htl, prescription = presc, method = "octave",
           desensitization = FALSE, transducer = "none")

cat("A1 Sones natively:", obj$loudness_monaural, "\n")
