source("R/sii.R")
source("R/open_nl.R")
source("R/benchmark_targets.R")
Rcpp::sourceCpp("src/bramslow2004.cpp")

d <- setup_data()
f_htl <- c(250, 500, 1000, 2000, 4000, 8000)
threshold <- jd2011_targets$a1$threshold

# Natively compute open_nl
target <- open_nl(speech = 65, threshold = threshold, freq = f_htl, loss = rep(0, 6))

obj <- sii(speech = target$speech, threshold = target$threshold, loss = target$loss,
           freq = target$freq, prescription = target, method = "octave",
           desensitization = "none", transducer = "none")

cat("Native target gain:", target$gain, "\n")
cat("obj E'i:", obj$table$"E'i", "\n")

l_res <- calculate_loudness(obj)
cat("Shiny monaural loudness:", l_res$total, "\n")

bin_l <- SII:::calculate_binaural_loudness(obj, obj)
cat("Shiny bilateral loudness:", bin_l, "\n")

